"""Regression for LiteLLM #45348: done-only tool arguments survive exactly once."""
import unittest
from litellm.completion_extras.litellm_responses_transformation.transformation import OpenAiResponsesToChatCompletionStreamIterator as Bridge
from litellm.llms.chatgpt.chat.streaming_utils import ChatGPTToolCallNormalizer

class ToolArguments(unittest.TestCase):
    def check_calls(self, modes):
        bridge=Bridge(streaming_response=None,sync_stream=True)
        events=[];expected={}
        for i,mode in enumerate(modes):
            args='{"city":"city-%d"}'%i;expected[i]=args
            events.append({'type':'response.output_item.added','output_index':i,'item':{'type':'function_call','id':f'fc_{i}','call_id':f'call_{i}','name':'weather','arguments':args if mode=='added' else ''}})
            if mode=='delta':
                for part in (args[:5],args[5:]):events.append({'type':'response.function_call_arguments.delta','output_index':i,'item_id':f'fc_{i}','delta':part})
            for _ in range(2):events.append({'type':'response.function_call_arguments.done','output_index':i,'item_id':f'fc_{i}','arguments':args})
        chunks=ChatGPTToolCallNormalizer(iter(bridge.chunk_parser(e) for e in events))
        actual={}
        for c in chunks:
            for t in c.choices[0].delta.tool_calls or []:actual[t.index]=actual.get(t.index,'')+(t.function.arguments or '')
        self.assertEqual(actual,expected)
    def test_done_only_parallel_calls(self):self.check_calls(['done','done','done'])
    def test_deltas_not_duplicated(self):self.check_calls(['delta','delta'])
    def test_mixed_delivery(self):self.check_calls(['done','delta','added'])

if __name__=='__main__':unittest.main()
