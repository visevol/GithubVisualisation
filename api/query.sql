SELECT source_files.filepath, SUM(additions - deletions) as line_count
FROM source_file_changes
INNER JOIN source_files ON source_files.id = source_file_changes.source_file_id
INNER JOIN commits AS pin ON pin.repository_id = 1 AND pin.commit_hash = 'd82f73ecabe71fc3814eff0bd26f4f431f690266'
INNER JOIN commits ON TRUE
  AND commits.id = source_file_changes.commit_id
  AND commits.id <= pin.id
  AND commits.for_file_size = 1
  AND commits.repository_id = 1
GROUP BY source_files.id
HAVING line_count > 0
