const { BedrockAgentClient, StartIngestionJobCommand } = require("@aws-sdk/client-bedrock-agent");

const client = new BedrockAgentClient({ region: "us-east-1" });

exports.handler = async (event) => {
  console.log("Received S3 event:", JSON.stringify(event, null, 2));

  const knowledgeBaseId = process.env.KNOWLEDGE_BASE_ID;
  if (!knowledgeBaseId) {
    throw new Error("Missing KNOWLEDGE_BASE_ID environment variable");
  }

  try {
    const command = new StartIngestionJobCommand({
      knowledgeBaseId,
      dataSourceId: "kb-s3-source"
    });

    const response = await client.send(command);
    console.log("Ingestion job started:", JSON.stringify(response, null, 2));

    return {
      statusCode: 200,
      body: JSON.stringify({ message: "Ingestion job triggered", response }),
    };
  } catch (err) {
    console.error("Error starting ingestion job:", err);
    throw err;
  }
};
