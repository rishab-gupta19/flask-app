apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: product-backend
  template:
    metadata:
      labels:
        app: product-backend
    spec:
      containers:
      - name: flask-container
        image: gcr.io/rishab-gupta-cwx-internal/product-backend
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
        env:
        - name: DB_USER
          value: "${DB_USER}"
        - name: DB_PASSWORD
          value: "${DB_PASSWORD}"
        - name: DB_HOST
          value: "${DB_HOST}"
        - name: DB_PORT
          value: "${DB_PORT}"
        - name: DB_NAME
          value: "${DB_NAME}"
        - name: API_TOKEN
          value: "${API_TOKEN}"
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 15
          periodSeconds: 20

