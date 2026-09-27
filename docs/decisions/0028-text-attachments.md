# 0028: Attach text files by copying their content into the message

**Status:** Accepted

## Context
Users want to give the agent a file: a spec, a log, a file from another project. The agent's
tools can already read project files, but only inside the project, and only if the model
decides to.

## Decision
- **Text files only for now**, read by an `AttachmentLoading` service in Infrastructure.
  Images are refused with a message until vision support exists (planned).
- **The content is copied into the message when attached** and stored with it (JSON column),
  not referenced by path: the conversation stays reproducible when files change or disappear.
- **Sent as `<file path="…">` blocks after the user's text**, a format models handle well,
  with the project-relative path so the model can act on project files with its tools.
- **Not confined to the project**: the user picks the file. Limits keep one attachment from
  filling the context (2 MB read, 100K characters kept, 10 files).

## Alternatives
- **Store only the path and read at each run**: smaller database, but history changes behind
  the user's back and breaks when a file moves.
- **Attach a reference and let the agent read it with `read_file`**: costs a model step, and
  the tools cannot reach files outside the project.
- **Images now**: needs a per-provider message format (Ollama `images`, OpenAI content parts),
  capability checks and storage for binary data; planned separately.

## Consequences
- Large attachments make the database and every later request of the session larger; the
  context manager and summaries treat them like any message text.
- A file edited after being attached is sent in its old version; attach it again to update it.
