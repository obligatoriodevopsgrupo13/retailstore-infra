const {
  ECSClient,
  ListServicesCommand,
  DescribeServicesCommand,
} = require("@aws-sdk/client-ecs");
const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");

const ecs = new ECSClient();
const sns = new SNSClient();

exports.handler = async (event) => {
  const clusterName = process.env.CLUSTER_NAME;
  const environment = process.env.ENVIRONMENT ?? "unknown";

  const { serviceArns } = await ecs.send(
    new ListServicesCommand({ cluster: clusterName }),
  );

  if (!serviceArns || serviceArns.length === 0) {
    console.log(`No se encontraron servicios en el cluster ${clusterName}`);
    return { statusCode: 200, body: "No services found" };
  }

  const { services } = await ecs.send(
    new DescribeServicesCommand({
      cluster: clusterName,
      services: serviceArns,
    }),
  );

  const degraded = [];
  const healthy = [];

  for (const { serviceName, desiredCount, runningCount } of services) {
    if (runningCount < desiredCount) {
      degraded.push(
        `  [DEGRADADO] ${serviceName}: deseado=${desiredCount}, corriendo=${runningCount}`,
      );
    } else {
      healthy.push(
        `  [OK] ${serviceName}: ${runningCount}/${desiredCount} tareas corriendo`,
      );
    }
  }

  if (degraded.length === 0) {
    console.log(
      `Todos los servicios estan saludables en el cluster ${clusterName}`,
    );
    return { statusCode: 200, body: "All services healthy" };
  }

  const message = [
    "Alerta de salud en el cluster ECS.",
    "",
    `Cluster  : ${clusterName}`,
    `Ambiente : ${environment}`,
    "",
    `Servicios degradados (${degraded.length}/${services.length}):`,
    ...degraded,
    "",
    `Servicios saludables (${healthy.length}/${services.length}):`,
    ...healthy,
    "",
    "Revisar en la consola de ECS:",
    `https://console.aws.amazon.com/ecs/v2/clusters/${clusterName}/services`,
  ].join("\n");

  const subject =
    `[ECS HEALTH] ${degraded.length} servicio(s) degradado(s) en ${environment}`.slice(
      0,
      100,
    );

  await sns.send(
    new PublishCommand({
      TopicArn: process.env.SNS_TOPIC_ARN,
      Subject: subject,
      Message: message,
    }),
  );

  console.log(`Alerta enviada: ${degraded.length} servicio(s) degradado(s)`);
  return {
    statusCode: 200,
    body: `${degraded.length} degraded services reported`,
  };
};
