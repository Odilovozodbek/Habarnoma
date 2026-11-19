import 'package:flutter_test/flutter_test.dart';
import 'package:havola/main.dart';
void main(){
  test('Accept only public source links',(){
    expect(channelName('https://t.me/Example_channel'),'example_channel');
    expect(channelName('@Example_channel'),'example_channel');
    expect(channelName('https://t.me/+secret'),isNull);
    expect(channelName('https://evil.com/example'),isNull);
    expect(channelName('https://t.me/example/123'),isNull);
  });
}
