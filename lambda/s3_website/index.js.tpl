const { SSMClient, GetParameterCommand } = require('@aws-sdk/client-ssm');

const client = new SSMClient({ region: 'us-east-1' });
const PARAMETER_NAME = "${parameter_name}";
const CACHE_TTL_MS = 60 * 1000;

const OLD_SITE_DOMAIN = "${old_site_domain}";
const NEW_SITE_DOMAIN = "${new_site_domain}";

let cachedValue = null;
let cacheExpiresAt = 0;

async function getRollbackValue() {
  const now = Date.now();

  if (cachedValue !== null && now < cacheExpiresAt) {
    console.log("SSM: usando valor em cache:", cachedValue);
    return cachedValue;
  }

  console.log("SSM: buscando parâmetro...");
  const command = new GetParameterCommand({
    Name: PARAMETER_NAME,
    WithDecryption: false,
  });

  const response = await client.send(command);
  cachedValue = response.Parameter.Value;
  cacheExpiresAt = now + CACHE_TTL_MS;

  console.log("SSM: valor obtido e cacheado:", cachedValue);
  return cachedValue;
}

exports.handler = async (event, context, callback) => {
  const request = event.Records[0].cf.request;

  try {
    const rollback = await getRollbackValue();

    let domain;
    if (rollback === "true") {
      domain = OLD_SITE_DOMAIN;
    } else if (rollback === "false") {
      domain = NEW_SITE_DOMAIN;
    } else {
      console.warn("SSM unexpected value:", rollback, "— using fallback");
      domain = NEW_SITE_DOMAIN;
    }

    request.origin = {
      custom: {
        domainName: domain,
        port: 80,
        protocol: "http",
        path: "",
        sslProtocols: ["TLSv1.2"],
        readTimeout: 30,
        keepaliveTimeout: 5,
        customHeaders: {},
      },
    };

    request.headers["host"] = [{ key: "Host", value: domain }];
    callback(null, request);

  } catch (err) {
    console.error("Erro ao buscar parâmetro SSM:", err);
    callback(null, request);
  }
};