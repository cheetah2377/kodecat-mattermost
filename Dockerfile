ARG MM_IMAGE_TAG=10.5
FROM mattermost/mattermost-team-edition:${MM_IMAGE_TAG}

# Copy management scripts into the image (no bind mounts needed)
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh
