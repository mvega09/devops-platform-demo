# DevOps Platform Demo 🌟

## 🚀 Introducción
Este proyecto es una **plataforma DevOps end-to-end** diseñada para demostrar habilidades profesionales en:

- Desarrollo de aplicaciones con Python/FastAPI
- Contenerización con Docker
- Orquestación con Kubernetes
- Infraestructura como código con Terraform
- Automatización CI/CD con GitHub Actions
- Observabilidad y monitoreo con Prometheus y Grafana
- Buenas prácticas de seguridad y DevSecOps

**Problema que resuelve:**  
Despliegues manuales, ambientes inconsistentes, falta de visibilidad y errores humanos frecuentes en entornos de producción.

---

## 🏗 Arquitectura del Proyecto

```text
          +---------------------+
          |      GitHub         |
          |  (Repo + Actions)  |
          +---------+-----------+
                    |
                    v
          +---------------------+
          |   CI/CD Pipeline    |
          | Test → Build → Scan |
          | Push → Deploy → Monitor |
          +---------+-----------+
                    |
                    v
          +---------------------+
          |   Docker Registry   |
          +---------+-----------+
                    |
                    v
          +---------------------+
          |   Kubernetes Cluster|
          |  Deployment / Pods  |
          +----+----------+----+
               |          |
               v          v
         Prometheus    Grafana Dashboard
