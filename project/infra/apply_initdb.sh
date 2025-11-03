# define namespace
NAMESPACE=citus
# Encuentra el pod del coordinator
POD=$(kubectl get pods -n $NAMESPACE -l app=citus-coordinator -o jsonpath="{.items[0].metadata.name}")
kubectl cp infra/initdb/01_create_pacientes.sql $NAMESPACE/$POD:/tmp/01_create_pacientes.sql
kubectl exec -n $NAMESPACE $POD -- psql -U postgres -f /tmp/01_create_pacientes.sql
