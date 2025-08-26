FROM n8nio/n8n:latest

USER root
RUN apk  update  &&\
        apk add --no-cache python3 py3-pip ffmpeg  \ 
        ca-certificates tzdata gcc musl-dev yt-dlp &&\
        mkdir -p /home/node/project &&\
        chown -R node:node /home/node/project 
 
USER node
