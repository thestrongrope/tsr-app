# The gateway for the production stack (docker-compose.yml): nginx with the route table copied in, so production mounts no file
# from the checkout. The dev and test stacks mount default.conf directly (docker-compose.dev.yml) and do not use this image.
FROM nginx:1.27-alpine
COPY default.conf /etc/nginx/conf.d/default.conf
