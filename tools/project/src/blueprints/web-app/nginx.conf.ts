import { GeneratorOptions } from '../types';

export function nginxConf(options: GeneratorOptions): string {
  return `server {
    listen 80;
    server_name localhost;

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # Redirigir /dashboard a la raíz (para corregir el problema)
    location /dashboard {
        return 301 /;
    }

    # Para solicitudes API, proxy al backend
    location /api {
        proxy_pass http://app-server:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\\n";
    }
}`;
}
