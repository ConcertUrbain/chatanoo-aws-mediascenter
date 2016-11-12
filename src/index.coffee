gm = require('gm').subClass( imageMagick: true )
async = require 'async'

aws = require 'aws-sdk'
s3 = new aws.S3();
transcoder = new aws.ElasticTranscoder(apiVersion: '2012-09-25')

config = null;
loadConfig = (event, callback)->
  return callback(null, config) if config
  bucket = event.Records[0].s3.bucket.name

  params =
    Bucket: bucket
    Key: 'pipeline.config'

  s3.getObject params, (err, data)->
    return callback(err) if err

    config = JSON.parse(data.Body.toString());
    callback(null, config)

exports.handler = (event, context) ->
  console.log 'Received event:', JSON.stringify(event, null, 2)

  loadConfig event, (err, config)->
    if err
      console.log err
      return context.succeed()

    # Get the object from the event and show its content type
    bucket = event.Records[0].s3.bucket.name
    key = event.Records[0].s3.object.key

    outputBucket = config.output_bucket

    mediaId = key.replace(/\.[^/.]+$/, '').substring(7) # remove upload folder and special caracter
    transcoderType = null
    switch true
      when /M-[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/i.test(mediaId)
        transcoderType = 'video'
        outputs = [
          { Key: "video.mp4",     PresetId: config.mp4_preset }
          { Key: "video.webm",    PresetId: config.webm_preset }
          { Key: "video.flv",     PresetId: config.flv_preset }
          { Key: "hls-400k/part", PresetId: config.hls400k_preset, SegmentDuration: "2" }
          { Key: "hls-1m/part",   PresetId: config.hls1m_preset, SegmentDuration: "2" }
          { Key: "hls-2m/part",   PresetId: config.hls2m_preset, SegmentDuration: "2" }
        ]
        playlists = [{
          Name: "playlist"
          Format: "HLSv3"
          OutputKeys: [
            "hls-400k/part"
            "hls-1m/part"
            "hls-2m/part"
          ]
        }]

      when /A-[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/i.test(mediaId)
        transcoderType = 'audio'
        outputs = [
          { Key: "audio.mp3", PresetId: config.mp3_preset }
          { Key: "audio.ogg", PresetId: config.ogg_preset }
        ]

      when /P-[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/i.test(mediaId)
        transcoderType = 'image'

      else
        console.log 'No actions'
        return context.succeed()

    if transcoderType in ['video', 'audio'] and outputs
      params =
        Input:
          Key: key
        PipelineId: config.pipeline
        Outputs: outputs
        OutputKeyPrefix: "#{mediaId}/"

      if playlists
        params.Playlists = playlists

      transcoder.createJob params, (err, data) ->
        if err
          console.log err, err.stack
          console.error 'Error Creating Job: ' + err
          context.fail()
        else
          console.log data
          context.succeed()

    else if transcoderType is 'image'
      async.waterfall [
          (next)-> s3.getObject({ Bucket: bucket, Key: key }, next)
          (res, next)->
            gm(res.Body).size (err, size)->
              scalingFactor = Math.min(
                parseInt(config.img_max_width) / size.width,
                parseInt(config.img_max_height) / size.height
              )
              width  = scalingFactor * size.width;
              height = scalingFactor * size.height;
              @resize(width, height).toBuffer 'png', (err, buffer)->
                next(err) if err
                next(null, res.ContentType, buffer)
          (contentType, data, next)->
            params =
              Bucket: outputBucket
              Key: "#{mediaId}/image.png"
              Body: data
              ContentType: contentType
            s3.putObject(params, next)
        ], (err)->
          if err
            console.log err, err.stack
            console.error 'Error Creating Job: ' + err
            context.fail()
          else
            context.succeed()

    else
      console.log 'No actions'
      return context.succeed()
