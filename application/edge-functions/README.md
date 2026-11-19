# Edge functions

| File | What happens to it |
| --- | --- |
| `image-request.js` | Viewer-request function. Packaged by the Task 5 stack when the paid gate is on. Not published from this workspace. |
| `cache-headers.js` | Viewer-response function. Same gate. Versioned product keys are `immutable`. |
| `query-filter.js` | Local helper and tests. It is not the associated handler. |
| `webp.js` | Local tests only. The handler does not convert, because no encoder is packaged. |
| `signed-url.js` | Local tests only. The handler refuses to run at the edge. |

None of these files have been published in `us-east-1`. A Node test is not a Lambda@Edge invocation. The image cache key is the object path. Query parameters are not part of that key.
