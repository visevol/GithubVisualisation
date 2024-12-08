# Programmer's guide

# Backend

## Setup (local)

[Rails backend development setup](../api/README.md)

### Tests & Lint

To run tests :
```
cd api/
bin/rails test
```

To run lint and autocorrect :
```
cd api/
bin/rubocop -A
```

## Docker
```
docker build . -t fastapi 
docker run -d --name fastapi -p 80:80 fastapi
```

va rouler sur http://127.0.0.1/docs (ou local host)

## Caching

`pydriller` fonctionne d'une façon très lente pour notre besoin : ne permet pas d'accéder rapidement à une tranche de commit, la librairie clone le repo en entier et traite tous les commits (même si ce n'est pas demandé).

Pour pallier cette lacune, nous avons implémenté un mécanisme de caching avec TinyDB (permet de maintenir une DB locale de format `.json`)

Voici comment le caching fonctionne pour un repo donné :

* L'utilisateur fait une requête pour avoir les commits d'un repo
* L'API vérifie dans la DB (`cache/db.json`) pour une entrée pour ce repo
* S'il n'y en a pas, pydriller prend le repo *entier* et store les commits dans la DB
* 


## Custom pydriller

Ce repo a besoin d'une [version modifiée de pydriller](https://github.com/cedric-audy/pydriller/) (la version originale fonctionne mais est beaucoup moins performante). Le package se trouve dans `pydriller/`

Si vous voulez re-package, cloner le [repo](https://github.com/cedric-audy/pydriller/), run :
`python setup.py sdist bdist_wheel`

Copier coller le fichier .whl dans `/dist` vers le `pydriller/` du présent repo.

# Frontend

## Installation
- Create new `.env` file at root of project
- Paste the content of the `.env.example` file to the new .env file
- Install dependencies: `npm install`
- To start to project: `npm run dev`

## Docker

- Create docker container: `docker build . -t "frontend"`
- Run the container: `docker run -d -p 8080:8080 frontend`
- Access the application: [http://localhost:8080/](http://localhost:8080/)
