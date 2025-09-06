# Use lightweight Nginx base image
FROM nginx:alpine

# Remove default Nginx content
RUN rm -rf /usr/share/nginx/html/*

# Copy the entire build folder into Nginx html directory
COPY build/ /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Start Nginx in background
CMD ["sh", "-c", "nginx & tail -f /dev/null"]
