# Use a Node.js base image. Use the latest LTS version for stability.
FROM node:18-alpine

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json to the work directory
# This step is crucial for dependency caching.
COPY package*.json ./

# Install all dependencies as specified in package.json
RUN npm install

# Copy the rest of your application's source code to the container
COPY . .

# Run the build task for your frontend if it's a monorepo with Turborepo
# This is necessary to create the static assets that will be served.
RUN npx turbo run build --filter=frontend-app

# Expose the port your frontend server runs on (e.g., 3000, or whatever is configured)
EXPOSE 3000

# Set the command to run your application.
# This will execute the "start" script defined in your package.json.
CMD ["npm", "turbo", "run", "start"]
