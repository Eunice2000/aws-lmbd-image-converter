const AWS = require('aws-sdk');
const Sharp = require('sharp');

const s3 = new AWS.S3();
AWS.config.update({ region: 'us-east-1' });

exports.handler = async (event, context) => {
  try {
    const bucket = 'lambda-new-image-bucket'; // Replace with your S3 bucket name
    // List all objects in the S3 bucket
    const objects = await s3.listObjectsV2({ Bucket: bucket }).promise();
    // Process each image in the bucket
    const imagePromises = objects.Contents.map((object) => processImage(bucket, object.Key, object));
    await Promise.all(imagePromises);
    return 'Success';
  } catch (error) {
    console.error(error);
    throw error;
  }
};

async function processImage(bucket, key, object) {
  const image = await s3.getObject({ Bucket: bucket, Key: key }).promise();
  const ext = key.substring(key.lastIndexOf("."))
  if (ext === '.png') {
    const thumbnail = await Sharp(image.Body)
      .resize(20, 20)
      .toBuffer();
    const thumbnailKey = `${key}-thumbnail.png`
    await s3
      .putObject({
        Bucket: bucket,
        Key: thumbnailKey,
        Body: thumbnail,
        ContentType: 'image/png',
      })
      .promise();
    console.log(`Thumbnail image with the name ${thumbnailKey} has been uploaded to ${bucket}`);
  } else {
    console.log(`Image is not a PNG. No thumbnail conversion required.`);
  }
}
