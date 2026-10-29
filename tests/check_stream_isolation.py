import asyncio,importlib,json
from litellm.types.utils import ModelResponseStream
try:
 from litellm.llms.anthropic.pass_through.adapters.streaming_iterator import AnthropicStreamWrapper
except ImportError:
 from litellm.llms.anthropic.experimental_pass_through.adapters.streaming_iterator import AnthropicStreamWrapper
async def source(name):
 yield ModelResponseStream(id='probe-'+name,model='gpt-6.1-sol',choices=[{'index':0,'delta':{'tool_calls':[{'index':0,'id':'call-'+name,'type':'function','function':{'name':'probe','arguments':json.dumps({'owner':name})}}]},'finish_reason':None}])
 yield ModelResponseStream(id='probe-'+name,model='gpt-6.1-sol',choices=[{'index':0,'delta':{},'finish_reason':'tool_calls'}])
async def main():
 a=AnthropicStreamWrapper(source('A'),'gpt-6.1-sol');b=AnthropicStreamWrapper(source('B'),'gpt-6.1-sol')
 events={'A':[],'B':[]}
 for name,s in [('A',a),('B',b)]:
  events[name].append(await anext(s));events[name].append(await anext(s))
 for _ in range(12):
  for name,s in [('A',a),('B',b)]:
   try:events[name].append(await anext(s))
   except StopAsyncIteration:pass
 errors=[]
 for name,es in events.items():
  open_blocks=set();seen=set();args='';ids=[]
  for e in es:
   t=e['type'];i=e.get('index')
   if t=='content_block_start':
    if i in seen:errors.append(f'{name}: duplicate block start {i}')
    seen.add(i);open_blocks.add(i)
    if e['content_block'].get('id'):ids.append(e['content_block']['id'])
   elif t=='content_block_delta':
    if i not in open_blocks:errors.append(f'{name}: delta for unopened/closed block {i}')
    args+=e['delta'].get('partial_json','')
   elif t=='content_block_stop':
    if i not in open_blocks:errors.append(f'{name}: stop for unopened/closed block {i}')
    open_blocks.discard(i)
  if ids!=['call-'+name]:errors.append(f'{name}: wrong/crossed stream tool IDs {ids}')
  if not args or json.loads(args)!={'owner':name}:errors.append(f'{name}: missing/crossed arguments')
  if open_blocks:errors.append(f'{name}: unclosed blocks {open_blocks}')
 print(json.dumps({'errors':errors,'events':{k:[(e['type'],e.get('index')) for e in es] for k,es in events.items()}}))
 assert not errors,errors
asyncio.run(main())
