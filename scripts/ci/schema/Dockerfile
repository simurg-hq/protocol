# Tooling image for JSON Schema validation of schema/ and fixtures/.
FROM python:3.14.8-alpine

RUN pip install --no-cache-dir check-jsonschema==0.38.2

ENTRYPOINT ["check-jsonschema"]
