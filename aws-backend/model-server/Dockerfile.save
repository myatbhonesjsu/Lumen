FROM pytorch/pytorch:latest

WORKDIR /app

# Install small runtime deps
RUN pip install --no-cache-dir fastapi uvicorn[standard] pillow

# Copy server code
COPY app.py /app/
COPY labels.json /app/
COPY models /app/models

EXPOSE 8080

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
