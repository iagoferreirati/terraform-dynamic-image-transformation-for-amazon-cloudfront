const { LambdaClient, InvokeCommand } = require("@aws-sdk/client-lambda");
const { HeadObjectCommand, S3Client } = require("@aws-sdk/client-s3");

const lambda = new LambdaClient({});
const s3 = new S3Client({});

function emitMetrics({ originalBytes, optimizedBytes, statusCode }) {
  const savedBytes = Math.max(0, originalBytes - optimizedBytes);
  const savedPercent = originalBytes > 0 ? (savedBytes / originalBytes) * 100 : 0;

  console.log(JSON.stringify({
    _aws: {
      Timestamp: Date.now(),
      CloudWatchMetrics: [{
        Namespace: process.env.METRICS_NAMESPACE,
        Dimensions: [["Service"]],
        Metrics: [
          { Name: "OriginalBytes", Unit: "Bytes" },
          { Name: "OptimizedBytes", Unit: "Bytes" },
          { Name: "SavedBytes", Unit: "Bytes" },
          { Name: "SavedPercent", Unit: "Percent" },
          { Name: "ProcessedImages", Unit: "Count" },
          { Name: "ProcessingErrors", Unit: "Count" },
        ],
      }],
    },
    Service: process.env.METRICS_SERVICE,
    OriginalBytes: originalBytes,
    OptimizedBytes: optimizedBytes,
    SavedBytes: savedBytes,
    SavedPercent: savedPercent,
    ProcessedImages: statusCode >= 200 && statusCode < 400 ? 1 : 0,
    ProcessingErrors: statusCode >= 400 ? 1 : 0,
  }));
}

async function originalSize(event) {
  // Direct URLs map exactly to the S3 key. Thumbor-style URLs with filters are
  // still processed, but are intentionally excluded from reduction metrics to
  // avoid guessing the object key from a transformation expression.
  const key = event.pathParameters?.proxy;
  if (!key || key.startsWith("filters:")) return 0;

  try {
    const response = await s3.send(new HeadObjectCommand({
      Bucket: process.env.SOURCE_BUCKET,
      Key: key,
    }));
    return response.ContentLength ?? 0;
  } catch (error) {
    console.warn("Could not determine original size", { name: error.name, key });
    return 0;
  }
}

exports.handler = async (event) => {
  const originalBytes = await originalSize(event);
  const invocation = await lambda.send(new InvokeCommand({
    FunctionName: process.env.IMAGE_HANDLER_FUNCTION_NAME,
    InvocationType: "RequestResponse",
    Payload: Buffer.from(JSON.stringify(event)),
  }));

  if (invocation.FunctionError) {
    throw new Error(`Image handler invocation failed: ${invocation.FunctionError}`);
  }

  const response = JSON.parse(Buffer.from(invocation.Payload).toString("utf8"));
  const optimizedBytes = response.isBase64Encoded
    ? Buffer.from(response.body || "", "base64").length
    : Buffer.byteLength(response.body || "", "utf8");

  if (originalBytes > 0) {
    emitMetrics({ originalBytes, optimizedBytes, statusCode: response.statusCode || 500 });
  }

  return response;
};
