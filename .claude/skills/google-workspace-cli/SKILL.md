---
name: google-workspace-cli
description: Use when the user mentions Google Drive, Google Docs, Sheets, Slides, Gmail, Calendar, Google files, shared drives, or wants to search, read, create, or edit any Google Workspace content. Accesses Google Workspace via the `gws` CLI.
---

# Google Workspace CLI (`gws`)

The `gws` CLI is installed globally and authenticated with the user's Google Workspace account. Use it via the Shell tool to interact with Google Drive, Docs, Sheets, Slides, Gmail, and Calendar.

## Command Pattern

```
gws <service> <resource> <method> [flags]
```

## Common Flags

| Flag | Purpose |
|------|---------|
| `--params '{...}'` | Query/path parameters as JSON |
| `--json '{...}'` | Request body as JSON |
| `--dry-run` | Validate without sending |
| `--page-all` | Fetch all pages (NDJSON output) |
| `--page-limit N` | Limit pages fetched (default: 10) |
| `--format table` | Output as table (also: json, yaml, csv) |
| `--upload ./file` | Upload file with multipart request |

## Drive

### Search files

```bash
gws drive files list --params '{"q": "name contains '\''quarterly report'\''", "pageSize": 10}'
```

### List recent files

```bash
gws drive files list --params '{"pageSize": 10, "orderBy": "modifiedTime desc"}'
```

### List files in a folder

```bash
gws drive files list --params '{"q": "'\''FOLDER_ID'\'' in parents"}'
```

### List shared drives

```bash
gws drive drives list
```

### Get file metadata

```bash
gws drive files get --params '{"fileId": "FILE_ID"}'
```

### Upload a file

```bash
gws drive +upload ./report.pdf --parent FOLDER_ID
```

### Export Google Workspace files

```bash
# Doc as PDF
gws drive files export --params '{"fileId": "FILE_ID", "mimeType": "application/pdf"}' > doc.pdf

# Sheet as CSV
gws drive files export --params '{"fileId": "FILE_ID", "mimeType": "text/csv"}' > data.csv
```

### Advanced search queries

The `q` parameter supports operators:

| Query | Example |
|-------|---------|
| By name | `name contains 'budget'` |
| By type | `mimeType = 'application/vnd.google-apps.document'` |
| By owner | `'user@example.com' in owners` |
| Shared with me | `sharedWithMe` |
| Starred | `starred = true` |
| Modified after | `modifiedTime > '2026-01-01T00:00:00'` |
| Combined | `name contains 'budget' and mimeType = 'application/pdf'` |

MIME types for Google Workspace files:

| Type | MIME |
|------|------|
| Document | `application/vnd.google-apps.document` |
| Spreadsheet | `application/vnd.google-apps.spreadsheet` |
| Presentation | `application/vnd.google-apps.presentation` |
| Folder | `application/vnd.google-apps.folder` |
| Form | `application/vnd.google-apps.form` |

## Docs

### Read a document

```bash
gws docs documents get --params '{"documentId": "DOCUMENT_ID"}'
```

The response contains the full document structure with text content in `body.content[].paragraph.elements[].textRun.content`.

### Create a document

```bash
gws docs documents create --json '{"title": "Meeting Notes"}'
```

### Append text (helper)

```bash
gws docs +write --document DOCUMENT_ID --text 'Hello, world!'
```

### Batch update (insert, format, replace)

```bash
gws docs documents batchUpdate --params '{"documentId": "DOCUMENT_ID"}' --json '{
  "requests": [
    {"insertText": {"location": {"index": 1}, "text": "New heading\n"}},
    {"updateTextStyle": {"range": {"startIndex": 1, "endIndex": 12}, "textStyle": {"bold": true}, "fields": "bold"}}
  ]
}'
```

### Replace text

```bash
gws docs documents batchUpdate --params '{"documentId": "DOCUMENT_ID"}' --json '{
  "requests": [{"replaceAllText": {"containsText": {"text": "OLD", "matchCase": true}, "replaceText": "NEW"}}]
}'
```

## Sheets

### Read values

```bash
gws sheets +read --spreadsheet SPREADSHEET_ID --range 'Sheet1!A1:B10'
```

### Read full sheet

```bash
gws sheets spreadsheets values get --params '{"spreadsheetId": "SPREADSHEET_ID", "range": "Sheet1"}'
```

### Append rows (helper)

```bash
gws sheets +append --spreadsheet SPREADSHEET_ID --values 'Alice,100,true'
gws sheets +append --spreadsheet SPREADSHEET_ID --json-values '[["Alice",100],["Bob",200]]'
```

### Write values

```bash
gws sheets spreadsheets values update \
  --params '{"spreadsheetId": "SPREADSHEET_ID", "range": "Sheet1!A1:B2", "valueInputOption": "USER_ENTERED"}' \
  --json '{"values": [["Name", "Score"], ["Alice", "95"]]}'
```

### Create a spreadsheet

```bash
gws sheets spreadsheets create --json '{"properties": {"title": "Q1 Budget"}}'
```

### Get spreadsheet metadata

```bash
gws sheets spreadsheets get --params '{"spreadsheetId": "SPREADSHEET_ID"}'
```

## Gmail

### List recent messages

```bash
gws gmail users messages list --params '{"userId": "me", "maxResults": 10}'
```

### Read a message

```bash
gws gmail users messages get --params '{"userId": "me", "id": "MESSAGE_ID"}'
```

### Send an email (helper)

```bash
gws gmail +send --to user@example.com --subject "Hello" --body "Hi there!"
```

### Search messages

```bash
gws gmail users messages list --params '{"userId": "me", "q": "from:alice@example.com subject:report"}'
```

## Calendar

### List today's events

```bash
gws calendar events list --params '{"calendarId": "primary", "timeMin": "2026-03-28T00:00:00Z", "timeMax": "2026-03-28T23:59:59Z", "singleEvents": true, "orderBy": "startTime"}'
```

Note: replace the date values with the actual current date. `singleEvents: true` is required for `orderBy: startTime` to work and expands recurring events into individual instances.

### List upcoming events

```bash
gws calendar events list --params '{"calendarId": "primary", "timeMin": "2026-03-23T00:00:00Z", "maxResults": 10, "singleEvents": true, "orderBy": "startTime"}'
```

### Create an event (helper)

```bash
gws calendar +insert --calendar primary --summary "Team Standup" --start "2026-03-24T10:00:00" --end "2026-03-24T10:30:00"
```

### Get event details

```bash
gws calendar events get --params '{"calendarId": "primary", "eventId": "EVENT_ID"}'
```

## Slides (Presentations)

### Get presentation

```bash
gws slides presentations get --params '{"presentationId": "PRESENTATION_ID"}'
```

### Create presentation

```bash
gws slides presentations create --json '{"title": "Q1 Review"}'
```

## Tips

- Always use the Shell tool to execute `gws` commands.
- Responses are JSON by default. Use `--format table` for human-readable output when displaying to the user.
- For large result sets, use `--page-all` with `--page-limit` to control volume.
- Use `--dry-run` before write operations to preview what will be sent.
- Use `gws <service> <resource> --help` to discover available methods for any API.
- Use `gws schema <service>.<resource>.<method>` to inspect the full API schema for a method.
- The CLI is authenticated against your Google account (run `gws auth login` if not yet done).
- For full documentation: https://googleworkspace-cli.mintlify.app/commands/overview
