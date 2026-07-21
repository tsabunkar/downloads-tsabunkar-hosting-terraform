import boto3
import urllib.parse

s3 = boto3.client('s3')
BUCKET = 'tsabunkar-downloads'


def lambda_handler(event, context):
    request = event['Records'][0]['cf']['request']
    uri = request['uri']

    if not uri.endswith('/'):
        return request

    prefix = uri.lstrip('/')
    decoded_uri = urllib.parse.unquote(uri)

    try:
        resp = s3.list_objects_v2(
            Bucket=BUCKET,
            Prefix=prefix,
            Delimiter='/'
        )
    except Exception as e:
        return {
            'status': '500',
            'statusDescription': 'Internal Server Error',
            'headers': {
                'content-type': [{'key': 'Content-Type', 'value': 'text/html'}],
            },
            'body': f'<html><body><h1>Error</h1><p>{e}</p></body></html>'
        }

    lines = []
    lines.append('<!DOCTYPE html>')
    lines.append('<html><head><meta charset="utf-8">')
    lines.append(f'<title>Index of {decoded_uri}</title>')
    lines.append('<style>')
    lines.append('body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;margin:40px auto;max-width:800px}')
    lines.append('h1{border-bottom:1px solid #ddd;padding-bottom:8px}')
    lines.append('ul{list-style:none;padding:0}')
    lines.append('li{padding:6px 0}')
    lines.append('a{text-decoration:none;color:#0366d6}')
    lines.append('a:hover{text-decoration:underline}')
    lines.append('.size{color:#586069;margin-left:12px;font-size:13px}')
    lines.append('</style></head><body>')
    lines.append(f'<h1>Index of {decoded_uri}</h1><ul>')

    if prefix:
        parent = '/'.join(uri.rstrip('/').split('/')[:-1]) + '/'
        lines.append(f'<li><a href="{parent}">../</a></li>')

    for folder in resp.get('CommonPrefixes', []):
        name = folder['Prefix'].rstrip('/').split('/')[-1] + '/'
        lines.append(f'<li><a href="/{folder["Prefix"]}">{name}</a></li>')

    for obj in resp.get('Contents', []):
        key = obj['Key']
        if key == prefix:
            continue
        name = key.split('/')[-1]
        size = obj['Size']
        lines.append(f'<li><a href="/{key}">{name}</a><span class="size">{_fmt(size)}</span></li>')

    lines.append('</ul></body></html>')

    return {
        'status': '200',
        'statusDescription': 'OK',
        'headers': {
            'content-type': [{'key': 'Content-Type', 'value': 'text/html'}],
        },
        'body': '\n'.join(lines)
    }


def _fmt(size):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size < 1024:
            return f'{size:.1f} {unit}'
        size /= 1024
    return f'{size:.1f} TB'
