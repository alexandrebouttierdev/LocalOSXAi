# Attachments

*Implemented for text files. Images are planned: they need a vision model and a new message
format for each provider, and are refused with an explanation until then.*

The user can attach files to a message ([ADR 0028](../decisions/0028-text-attachments.md)):
the paperclip of the composer, or dropping files anywhere on the conversation (the composer's
border turns accent and its hint says “Drop to attach”).

## What can be attached

`LocalAttachmentLoader` (Infrastructure/FileSystem) reads:

- **regular text files**, symlinks followed, at most `MessageAttachment.maxFileBytes` (2 MB);
- only the first `maxCharacters` characters (100,000, about 25K tokens) are kept, and the model
  is told when a file was cut;
- at most `maxPerMessage` (10) files per message; the same path is attached once.

Refused, with a reason under the composer (`AttachmentError`): folders, images (by extension),
binaries (not UTF-8, or containing a NUL byte), files too large or unreadable. The other files
of the same drop are kept.

## What the model sees

`AgentPrompt.userContent` appends the files after the text:

```
Review this

Attached file:

<file path="Sources/App.swift">
…
</file>
```

Paths are **relative to the project** for project files, so they match the paths the agent's
tools use and the model can edit the file; files elsewhere keep their absolute path. A message
may be files alone.

## Stored with the message

The text is read **once, when attached**, and saved with the message (`AgentMessage.attachments`,
SQLite `message.attachments`, migration `v4_message_attachments`). History, retries and
summaries replay the same content even if the file changes or is deleted. The transcript shows
each file as a chip (name, size; path in the tooltip) under the user's message.

## Budget

Attachments are part of the new message, which the context manager never drops: a message too
large for the model's context fails with the usual overflow error, which suggests a larger
context or a shorter message.

## Security

Attaching is the user's own action, so it is not confined to the project root, unlike the
agent's tools (docs/security/permissions.md). Only the files the user picks are read; the model
cannot ask for a file outside the project through an attachment.
