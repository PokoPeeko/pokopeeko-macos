"""Isolated Engine.IO v4 polling peer for the production Swift client; no user data."""
import json
import queue
import subprocess
import sys
import threading
import urllib.parse
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


def main():
    connections = {}
    result = dict(authenticated=False, validAppPayload=False,
                  receivedPrivateState=False, heartbeats=0, friendQueries=0, musicUpdates=0, validMusicPayload=False, musicRemovals=0, validMusicRemove=False)
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def reply(self, data, status=200):
            body = data.encode()
            self.send_response(status)
            self.send_header("Content-Type", "text/plain; charset=UTF-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path == "/test/results":
                with lock:
                    self.reply(json.dumps(result))
                return
            if url.path != "/socket.io/":
                self.reply("missing", 404)
                return
            query = urllib.parse.parse_qs(url.query)
            if "sid" not in query:
                sid = str(uuid.uuid4())
                with lock:
                    connections[sid] = queue.Queue()
                self.reply('0' + json.dumps(dict(sid=sid, upgrades=[],
                                                pingInterval=25000, pingTimeout=20000)))
                return
            with lock:
                outgoing = connections[query["sid"][0]]
            try:
                packets = [outgoing.get(timeout=2)]
            except queue.Empty:
                packets = ["2"]  # Engine.IO ping, client replies pong.
            while not outgoing.empty():
                packets.append(outgoing.get_nowait())
            self.reply("\x1e".join(packets))

        def do_POST(self):
            query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            with lock:
                outgoing = connections[query["sid"][0]]
            body = self.rfile.read(int(self.headers.get("Content-Length", "0"))).decode()
            for packet in body.split("\x1e"):
                if packet.startswith("40/user-status,"):
                    auth = json.loads(packet.split(",", 1)[1])
                    with lock:
                        result["authenticated"] = auth == dict(sessionId="00000000-0000-4000-8000-000000000000")
                    if not result["authenticated"]:
                        outgoing.put('44/user-status,{"message":"유효하지 않은 세션입니다."}')
                        continue
                    outgoing.put('40/user-status,{"sid":"isolated-namespace"}')
                    outgoing.put('42/user-status,' + json.dumps(["window_status:updated", dict(
                        userId="9f02a61e-2adc-4e23-b0ae-c47a9bd8c788", appTitle="Remote Editor",
                        taskDescription="Using app", updatedAt=2000)]))
                    outgoing.put('42/user-status,' + json.dumps(["music_status:updated", dict(
                        userId="9f02a61e-2adc-4e23-b0ae-c47a9bd8c788", artistName="Remote artist",
                        trackTitle="Paused song", status="PAUSE", updatedAt=2100)]))
                elif packet.startswith("42/user-status,"):
                    event = json.loads(packet.split(",", 1)[1])
                    with lock:
                        if event[0] == "window_status:update":
                            payload = event[1]
                            result["lastAppTitle"] = payload.get("appTitle")
                            valid = set(payload) == {"appTitle", "taskDescription"}
                            result["validAppPayload"] = valid
                            if payload.get("appTitle") == "활동 비공개":
                                result["receivedPrivateState"] = True
                        elif event[0] == "music_status:update":
                            result["musicUpdates"] += 1
                            payload = event[1]
                            result["lastMusicStatus"] = payload.get("status")
                            result["validMusicPayload"] = (set(payload) == {"trackTitle", "artistName", "status"}
                                                           and payload["status"] in {"PLAYING", "PAUSE"}
                                                           and payload["trackTitle"] == "Local song"
                                                           and payload["artistName"] == "Local artist")
                        elif event[0] == "music_status:remove":
                            result["musicRemovals"] += 1
                            result["validMusicRemove"] = event == ["music_status:remove"]
                            outgoing.put('42/user-status,' + json.dumps(["music_status:removed", dict(
                                userId="9f02a61e-2adc-4e23-b0ae-c47a9bd8c788")]))
                        elif event[0] == "user_status:heartbeat":
                            result["heartbeats"] += 1
                        elif event[0] == "friends_status:get":
                            result["friendQueries"] += 1
            self.reply("ok")

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    import os
    environment = dict(os.environ, PRESENCE_TEST_URL=f"http://127.0.0.1:{server.server_port}")
    try:
        completed = subprocess.run([sys.argv[1]], env=environment, timeout=40)
    finally:
        server.shutdown()
        server.server_close()
    sys.exit(completed.returncode)


if __name__ == "__main__":
    main()
