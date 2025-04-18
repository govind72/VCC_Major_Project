import os
import threading
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import Response
import httpx
from kubernetes import client, config

app = FastAPI()

# Configuration from env
THRESHOLD = float(os.getenv("THRESHOLD", "0.8"))
APP_LABEL = os.getenv("APP_LABEL", "app=sample-app")
APP_PORT = int(os.getenv("APP_PORT", "8000"))
UPDATE_INTERVAL = int(os.getenv("UPDATE_INTERVAL", "10"))

pods_by_node = {}       # node_name -> [pod_ip, ...]
node_cpu_usage = {}     # node_name -> cpu_fraction

@app.on_event("startup")
def startup_event():
    # Load in-cluster config
    config.load_incluster_config()
    threading.Thread(target=update_loop, daemon=True).start()

def update_loop():
    v1 = client.CoreV1Api()
    metrics = client.CustomObjectsApi()
    while True:
        try:
            # 1) List all running pods with our label
            pods = v1.list_pod_for_all_namespaces(label_selector=APP_LABEL)
            pods_by_node.clear()
            for pod in pods.items:
                if pod.status.phase != "Running": continue
                node = pod.spec.node_name
                ip   = pod.status.pod_ip
                pods_by_node.setdefault(node, []).append(ip)

            # 2) Fetch node CPU usage from metrics.k8s.io
            m_nodes = metrics.list_cluster_custom_object(
                "metrics.k8s.io", "v1beta1", "nodes"
            )
            node_cpu_usage.clear()
            for item in m_nodes["items"]:
                name = item["metadata"]["name"]
                cpu_usage = item["usage"]["cpu"]  # e.g., "250m"
                # parse millicores
                if cpu_usage.endswith("m"):
                    used = float(cpu_usage[:-1]) / 1000
                else:
                    used = float(cpu_usage)
                cap = float(v1.read_node(name).status.capacity["cpu"])
                node_cpu_usage[name] = used / cap
        except Exception as e:
            print("Update failed:", e)
        finally:
            threading.Event().wait(UPDATE_INTERVAL)

def choose_node(local_node: str) -> str:
    # If local under threshold, serve locally
    if node_cpu_usage.get(local_node, 1.0) < THRESHOLD:
        return local_node
    # else pick least-used node under threshold
    candidates = [(n, cpu) for n, cpu in node_cpu_usage.items() if cpu < THRESHOLD]
    if candidates:
        return min(candidates, key=lambda x: x[1])[0]
    return local_node

@app.api_route("/{full_path:path}", methods=["GET","POST","PUT","DELETE","PATCH"])
async def proxy(full_path: str, request: Request):
    local_node = os.getenv("NODE_NAME")
    if not local_node:
        raise HTTPException(500, "NODE_NAME not provided")
    target_node = choose_node(local_node)
    pod_list = pods_by_node.get(target_node) or []
    if not pod_list:
        raise HTTPException(503, "No backends available")
    target_ip = pod_list[0]  # simple pick
    url = f"http://{target_ip}:{APP_PORT}/{full_path}"
    # forward
    async with httpx.AsyncClient() as client:
        resp = await client.request(
            request.method, url,
            headers={k:v for k,v in request.headers.items() if k.lower()!="host"},
            content=await request.body()
        )
    return Response(content=resp.content,
                    status_code=resp.status_code,
                    headers=resp.headers)
