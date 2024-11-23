FROM nginx:alpine3.20-slim

RUN rm /etc/nginx/conf.d/default.conf
RUN mkdir -p /etc/nginx/certs
COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html

CMD ["nginx", "-g", "daemon off;"]
