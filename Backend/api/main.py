from urllib.parse import urlparse

from fastapi import FastAPI, HTTPException, Response, status
from api.routers.commits_router import commits_router
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from api.database import engine
from api.models.repository import Repository


app = FastAPI()
### CORS ###
origins = [
    "http://localhost:8080",
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

### STARTING UP ###
app.include_router(commits_router)


@app.get("/repository")
def get_repository(url: str, response: Response):
    parsed_url = urlparse(url)
    hostname = parsed_url.hostname

    body = {
        "hostname": parsed_url.hostname,
        "path": parsed_url.path,
    }

    if hostname != "github.com":
        response.status_code = status.HTTP_400_BAD_REQUEST
        body["message"] = f"repositories on '{hostname}' are not supported."
        return body

    with Session(engine) as session:
        repository = session.query(Repository).filter(Repository.remote_url == url).first()

        if repository is None:
            response.status_code = status.HTTP_404_NOT_FOUND
            body["repository"] = None
            return body

        body["repository"] = {
            "id": repository.id,
            "remote_url": repository.remote_url,
        }

        return body
