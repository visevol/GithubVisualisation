import logging
from fastapi import FastAPI
from api.routers.commits_router import commits_router
from fastapi.middleware.cors import CORSMiddleware


### LOGGING ###
logging.basicConfig(format=' >>>>>>>>>>>> %(message)s', level=logging.ERROR)
logger = logging.getLogger(__name__)


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
logger.info('API is starting up')
app.include_router(commits_router)


@app.get("/repository")
def get_repository(url: str):
    print(f"fetching {url} ...")
