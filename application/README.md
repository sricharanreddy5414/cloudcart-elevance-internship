# Application

EverShop is the store. It is already running through Docker Compose on Windows, in `C:\Users\sri charan reddy\Desktop\Elevance-AWS-Internship`. This folder does not contain a second copy, and nothing here should be used to recreate that database volume.

| Path | Will hold |
| --- | --- |
| `evershop/` | Store-specific configuration we add deliberately, after the current Compose file has been read. |
| `docker/` | The production Dockerfile, kept separate from the development Compose file. |
| `lambda/` | The thumbnail function and the ClamAV scan function. |
| `edge-functions/` | Lambda@Edge source for query filtering, cache headers, and WebP conversion. |

No Dockerfile or function source has been added yet. The current step does not change the application.
