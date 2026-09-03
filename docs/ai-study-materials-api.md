# AI Study Materials API Contract

## Existing Plan Endpoint

`POST /ai/decks/plan` continues to create the AI study plan. The iOS app now sends these fields:

```json
{
  "topic": "CCNA Networking",
  "education_level": "University",
  "study_purpose": "Prepare for an Exam",
  "preparation_details": "CCNA exam covering routing, switching, and subnetting.",
  "learning_language": "Spanish",
  "target_date": "2026-10-01",
  "study_material_ids": ["material-id-1", "material-id-2"]
}
```

`preparation_details`, `learning_language`, `target_date`, and `study_material_ids` are optional. When `learning_language` is supplied, use it as the language the student wants to learn or practice. When it is `null`, omit language-specific behavior and generate the plan from the topic and other existing fields. The backend must accept `null` or an empty array for `study_material_ids`. When no material IDs are supplied, generate the plan using the topic and other existing fields exactly as before.

## Learning Depth

Learning depth is no longer a user-facing choice in the iOS app. Until the backend removes the field from its required plan schema, the app sends `"learning_depth": "Comprehensive"` internally on every request. This field is intentionally omitted from the user-facing request example above.

## Required Upload Endpoint

Implement an authenticated multipart endpoint before enabling file-context uploads in the app:

`POST /ai/study-materials`

Request:

- Multipart field name: `files`
- Supports multiple files in one request
- Accepted types: PDF, plain text, DOCX, PPTX

Response:

```json
{
  "materials": [
    {
      "id": "material-id-1",
      "filename": "networking-notes.pdf"
    }
  ]
}
```

The backend should extract and store each file's usable text, associate it with the authenticated user, and use the referenced material content only as supplemental context for `/ai/decks/plan`.

## iOS Integration

`AIStudyMaterialsView` uploads its selected file URLs to `/ai/study-materials`, receives the IDs, then sends those IDs as `study_material_ids` in the existing plan request. When the user selects no files, the app skips upload and sends an empty array; the topic-only flow remains unchanged.