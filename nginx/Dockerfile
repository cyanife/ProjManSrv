# https://registry.hub.docker.com/_/nginx/
FROM nginx:latest

# Copy customized nginx config file into container
COPY nginx.conf /etc/nginx/nginx.conf

# Copy project index.html into container
COPY index.html /usr/share/nginx/html/index.html