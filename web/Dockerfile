# Specter web platform (Next.js). Railway: new service from the same repo, Root Directory = web
FROM node:20-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
# the build needs the dev dependencies (typescript, tailwind), the migration script needs tsx
RUN npm ci --include=dev --no-audit --no-fund
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["sh", "-c", "npm run migrate && npm run start"]
