# Use a lightweight Python image
FROM python:3.11-slim

# Set the working directory in the container
WORKDIR /app

# Copy the requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

# Create the templates folder if it doesn't exist (safety check)
RUN mkdir -p /app/instance

# Expose the Flask port
EXPOSE 7990

# Run the application
CMD ["python", "app.py"]
