import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import sharp from 'sharp';

const s3Client = new S3Client({});
const PROCESSED_BUCKET = process.env.PROCESSED_BUCKET;

export async function handler(event) {
  console.log('Lambda invoked with event here:', JSON.stringify(event, null, 2));
  console.log('Environment:', {
    PROCESSED_BUCKET,
    AWS_REGION: process.env.AWS_REGION,
  });

  try {
    // Get the S3 bucket and key from the event
    const sourceBucket = event.Records[0].s3.bucket.name;
    const key = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, ' '));
    
    console.log('Processing file:', { sourceBucket, key });

    // Get the file from S3
    const getObjectResponse = await s3Client.send(
      new GetObjectCommand({
        Bucket: sourceBucket,
        Key: key,
      })
    );

    if (!getObjectResponse.Body) {
      throw new Error('No body in S3 response');
    }

    console.log('File metadata:', {
      contentType: getObjectResponse.ContentType,
      contentLength: getObjectResponse.ContentLength,
      metadata: getObjectResponse.Metadata,
    });

    // Convert the readable stream to a buffer
    const chunks = [];
    for await (const chunk of getObjectResponse.Body) {
      chunks.push(chunk);
    }
    const buffer = Buffer.concat(chunks);
    console.log('File loaded into buffer, size:', buffer.length);

    let outputBuffer;
    let outputKey = key;
    let contentType = getObjectResponse.ContentType;

    // If it's a HEIC file, convert it to JPEG
    if (key.toLowerCase().endsWith('.heic')) {
      console.log('Converting HEIC to JPEG');
      outputBuffer = await sharp(buffer, { animated: true })
        .jpeg({
          quality: 90,
          mozjpeg: true,
        })
        .toBuffer();
      outputKey = key.replace(/\.heic$/i, '.jpeg');
      contentType = 'image/jpeg';
      console.log('Conversion complete, new size:', outputBuffer.length);
    } else {
      console.log('Not a HEIC file, copying as-is');
      outputBuffer = buffer;
    }

    // Upload the file to the processed bucket
    console.log('Uploading to processed bucket:', {
      bucket: PROCESSED_BUCKET,
      key: outputKey,
      contentType,
    });

    await s3Client.send(
      new PutObjectCommand({
        Bucket: PROCESSED_BUCKET,
        Key: outputKey,
        Body: outputBuffer,
        ContentType: contentType,
        Metadata: {
          'original-key': key,
          'processed-by': 'heic-converter-lambda',
        },
      })
    );

    console.log(`Successfully processed ${key} and saved as ${outputKey}`);
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'File processed successfully',
        source: key,
        destination: outputKey,
        converted: key.toLowerCase().endsWith('.heic'),
      }),
    };
  } catch (error) {
    console.error('Error processing file:', error);
    throw error;
  }
} 