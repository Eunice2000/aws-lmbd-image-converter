// const AWS = require('aws-sdk');

// exports.handler = async (event) => {
//   // Set the region for the AWS SDK
//   AWS.config.update({ region: 'us-east-1' });  // Replace with your desired region

//   // Create an S3 client
//   const s3 = new AWS.S3();

//   // Specify the bucket name
//   const bucketName = 'lambda-new-image-bucket';  // Replace with your bucket name

//   try {
//     const response = await s3.listObjectsV2({ Bucket: bucketName }).promise();
//     const objects = response.Contents;

//     if (objects.length === 0) {
//       console.log(`No objects found in the bucket: ${bucketName}`);
//     } else {
//       console.log(`Objects in the bucket: ${bucketName}`);
//       objects.forEach((object) => {
//         const imageName = object.Key
//         const ext = imageName.substring(imageName.lastIndexOf("."))
//         console.log(ext)
//       });
//     }
//   } catch (error) {
//     console.error('Error retrieving objects from the bucket:', error);
//   }
// };

const AWS = require('aws-sdk');
const Sharp = require('sharp');

const s3 = new AWS.S3();
AWS.config.update({ region: 'us-east-1' });

async function processImage(bucket, key, object) {
  const image = await s3.getObject({ Bucket: bucket, Key: key }).promise();
  const ext = key.substring(key.lastIndexOf("."))
  if (ext === '.png') {
    const thumbnail = await Sharp(image.Body)
      .resize(20, 20)
      .toBuffer();

    const thumbnailKey = `${key}-thumbnail.png`;

    await s3
      .putObject({
        Bucket: bucket,
        Key: thumbnailKey,
        Body: thumbnail,
        ContentType: 'image/png',
      })
      .promise();
    console.log("Image", image)
    console.log("Object", bucket)

    console.log(`Thumbnail image uploaded is png`);
  } else {
    console.log(`Image is not a PNG. No thumbnail conversion required.`);
  }
}

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

