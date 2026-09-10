## Cases

1. A note owner can delete one of their notes through the notes service's HTTP API.
2. A deleted note stays in storage so that an operator can restore it on request.

## Problem type

Feature addition: a new write endpoint on an existing resource, with a read-side consequence for the owner's listing.

## Acceptance criteria

| AC id | criterion | source |
|-------|-----------|--------|
| AC1 | A note its owner has deleted no longer appears in that owner's `GET /notes` listing, on any page. | issue body |
| AC2 | `DELETE /notes/{id}` sent without an authenticated session is rejected with 401. | issue body |
| AC3 | The endpoint's OpenAPI description states that deletion is a soft delete. | issue body |
