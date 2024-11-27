import axios from "axios";
import Repository from "models/repository";
import RemoteRepository from "models/remoteRepository";

interface RepositorySearchResult {
  repository: Repository | null;
  remoteRepository: RemoteRepository | null;
}

export async function searchRepositoryByUrl(url: string): Promise<RepositorySearchResult> {
  const response = await axios.get('/repositories/search', { params: {url: url} });
  const result: RepositorySearchResult = {
    repository: null,
    remoteRepository: null,
  }

  if (response.data.repository) {
    result.repository = {
      id: response.data.repository.id,
      name: response.data.repository.name,
      domain: response.data.repository.domain,
      path: response.data.repository.path,
      url: response.data.repository.url,
      createdAt: new Date(response.data.repository.created_at),
      updatedAt: response.data.repository.updated_at,
      lastSyncedAt: response.data.repository.last_synced_at ? new Date(response.data.repository.last_synced_at) : null,
    }
  }

  if (response.data.remote_repository) {
    result.remoteRepository = {
      name: response.data.remote_repository.name,
      description: response.data.remote_repository.description,
      domain: response.data.remote_repository.domain,
      path: response.data.remote_repository.path,
      url: response.data.remote_repository.url,
    }
  }

  return result
}

export async function searchOrCreateRepository(url: string): Promise<Repository | null> {
  const response = await axios.post('/repositories', {url: url});
  if (response.status >= 400) {
    return null;
  }

  return {
    id: response.data.id,
    name: response.data.name,
    domain: response.data.domain,
    path: response.data.path,
    url: response.data.url,
    createdAt: new Date(response.data.created_at),
    updatedAt: new Date(response.data.updated_at),
    lastSyncedAt: response.data.last_synced_at ? new Date(response.data.last_synced_at) : null,
  }
}
