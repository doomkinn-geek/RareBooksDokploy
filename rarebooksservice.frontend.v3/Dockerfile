# 1) ���� ������ React-����������
FROM node:18-alpine AS build
WORKDIR /app

# �������� package.json, package-lock.json
COPY package*.json ./
RUN npm install

# �������� ���������
COPY . .
# �������� ������ (� Vite ��������� VITE_API_URL � �.�.)
RUN npm run build

# 2) ���� "runtime": nginx + �������
FROM nginx:stable-alpine

# �������� ����������� ����� ����� ������
COPY --from=build /app/dist /usr/share/nginx/html

# �������� ��������� ������ nginx, ��� �������� fallback �� index.html
COPY ./nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
