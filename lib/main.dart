import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const HavolaApp());
const bridge = MethodChannel('uz.havola/native');
const categories = <String, String>{'all':'Barchasi','hakaton':'Hakatonlar','tanlov':'Tanlovlar','tadbir':'Tadbirlar','universitet':'Universitet','musobaqa':'Musobaqalar','grant':'Grantlar'};
String? channelName(String value) => RegExp(r'^(?:https?://t\.me/|@)([A-Za-z][A-Za-z0-9_]{3,31})/?$').firstMatch(value.trim())?.group(1)?.toLowerCase();

class HavolaApp extends StatelessWidget {
  const HavolaApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner:false,title:'Havola',theme:ThemeData(brightness:Brightness.dark,useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff67edb3),brightness:Brightness.dark),scaffoldBackgroundColor:const Color(0xff0b121c)),home:const Dashboard());
}
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  List<Map<String,dynamic>> events=[],sources=[];
  Set<int> saved={};
  String category='all',query='',status='Server ulanmagan',url='',token='';
  bool sound=true,voice=false,busy=false,onlySaved=false;
  int tab=0;
  Timer? timer;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();timer=Timer.periodic(const Duration(seconds:60),(_){if(url.isNotEmpty)sync();});}
  @override void dispose(){timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed && url.isNotEmpty)sync();}
  void toast(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
  Future<void> load()async{
    try {
      final data=jsonDecode(await bridge.invokeMethod<String>('read')??'{}') as Map<String,dynamic>;
      url=data['url'] as String? ??'';token=data['token'] as String? ??'';
      sound=data['sound'] as bool? ??true;voice=data['voice'] as bool? ??false;
      saved=((data['saved'] as List?)??[]).map((e)=>(e as num).toInt()).toSet();
      final cache=await bridge.invokeMethod<String>('cached');
      if(cache!=null)events=(jsonDecode(cache) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      if(mounted)setState((){});
      if(url.isNotEmpty)await sync();
    }on MissingPluginException {toast('Bildirishnoma va ovoz Android qurilmada ishlaydi.');}
    catch(_){toast('Sozlamalarni yuklashda xato.');}
  }
  Future<void> persist()async{
    await bridge.invokeMethod('configure',{'json':jsonEncode({'url':url,'token':token,'sound':sound,'voice':voice,'saved':saved.toList()})});
  }
  Future<void> sync()async{
    if(busy||url.isEmpty)return;
    setState(()=>busy=true);
    try{
      final raw=await bridge.invokeMethod<String>('sync');
      final sourceRaw=await bridge.invokeMethod<String>('api',{'path':'/sources','method':'GET'});
      if(!mounted)return;
      setState((){events=(jsonDecode(raw??'[]') as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();sources=(jsonDecode(sourceRaw??'[]') as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();status='Yangilandi: ${TimeOfDay.now().format(context)}';});
    }on PlatformException catch(e){if(mounted)setState(()=>status=e.message??'Serverga ulanib bo‘lmadi');}
    catch(_){if(mounted)setState(()=>status='Server javobini o‘qib bo‘lmadi');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> addSource()async{
    if(url.isEmpty){toast('Avval sozlamalarda kuzatuvchi serverni ulang.');return;}
    final field=TextEditingController();String type='all';
    final value=await showDialog<Map<String,String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Kanal qo‘shish'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:field,decoration:const InputDecoration(labelText:'https://t.me/kanal_nomi')),const SizedBox(height:12),DropdownButtonFormField<String>(value:type,items:categories.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:(v)=>update(()=>type=v??'all'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Bekor qilish')),FilledButton(onPressed:(){final name=channelName(field.text);if(name==null){toast('Ochiq kanalning to‘liq havolasini kiriting.');return;}Navigator.pop(ctx,{'name':name,'filter':type});},child:const Text('Qo‘shish'))])));
    // Controller belongs to the route and is released after its exit animation.
    Future<void>.delayed(const Duration(seconds:1),field.dispose);
    if(value==null)return;
    try{await bridge.invokeMethod('api',{'path':'/sources','method':'POST','body':jsonEncode(value)});await sync();toast('Manba qo‘shildi. Keyingi e’lonlar kuzatiladi.');}on PlatformException catch(e){toast(e.message??'Manba qo‘shilmadi');}
  }
  Future<void> removeSource(String name)async{
    try{await bridge.invokeMethod('api',{'path':'/sources/$name','method':'DELETE'});await sync();}on PlatformException catch(e){toast(e.message??'Xato');}
  }
  Future<void> settingsSave(TextEditingController endpoint,TextEditingController secret)async{
    final next=endpoint.text.trim().replaceAll(RegExp(r'/+$'),'');
    final uri=Uri.tryParse(next);
    if(next.isNotEmpty&&(uri==null||uri.scheme!='https'||uri.host.isEmpty||uri.userInfo.isNotEmpty||uri.hasQuery||uri.hasFragment||uri.path.isNotEmpty)){toast('Faqat HTTPS server manzilini kiriting, masalan https://server.uz');return;}
    if(next.isNotEmpty&&secret.text.trim().isEmpty){toast('Server kirish tokenini kiriting.');return;}
    setState((){url=next;token=secret.text.trim();if(next.isEmpty){events=[];sources=[];status='Server ulanmagan';}});
    try{await persist();if(url.isNotEmpty)await sync();toast('Sozlamalar saqlandi.');}on PlatformException catch(e){toast(e.message??'Saqlanmadi');}
  }
  Future<void> speech(String text)async{try{await bridge.invokeMethod('speak',{'text':text});}on PlatformException catch(e){toast(e.message??'Ovoz ishlamadi');}}
  Widget empty(String title,String subtitle,IconData icon)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:58,color:const Color(0xff67edb3)),const SizedBox(height:20),Text(title,style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),const SizedBox(height:10),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60,height:1.5))])));
  Widget catalog(){
    final rows=events.where((e)=>(category=='all'||e['category']==category)&&(!onlySaved||saved.contains(e['id']))&&e['text'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,8,16,0),child:TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'E’lon qidirish',border:OutlineInputBorder()))),SizedBox(height:66,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(12),children:categories.entries.map((e)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(e.value),selected:category==e.key,onSelected:(_)=>setState(()=>category=e.key)))).toList())),SwitchListTile(dense:true,title:Text('${rows.length} ta e’lon'),subtitle:const Text('Faqat saqlanganlar'),value:onlySaved,onChanged:(v)=>setState(()=>onlySaved=v)),Expanded(child:rows.isEmpty?empty('Hali e’lon yo‘q',url.isEmpty?'Kuzatuvchi serverni ulang va kanal havolasini qo‘shing. Namunaviy e’lonlar ko‘rsatilmaydi.':'Tanlangan bo‘limda yangi e’lon hali kelmagan.',Icons.inbox_outlined):ListView.builder(itemCount:rows.length,itemBuilder:(ctx,i){final e=rows[i];return Card(margin:const EdgeInsets.fromLTRB(16,0,16,12),child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(categories[e['category']]??'E’lon',style:const TextStyle(color:Color(0xff67edb3))),const SizedBox(height:12),Text(e['text'].toString(),maxLines:8,overflow:TextOverflow.ellipsis),const SizedBox(height:14),Text('@${e['source']}',style:const TextStyle(color:Colors.white60)),Wrap(spacing:4,children:[TextButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Asl e’lon'),content:SingleChildScrollView(child:SelectableText('${e['text']}\n\n${e['url']}')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Yopish'))])),icon:const Icon(Icons.article_outlined),label:const Text('Batafsil')),IconButton(tooltip:'Ovozda o‘qish',onPressed:()=>speech(e['text'].toString()),icon:const Icon(Icons.volume_up_outlined)),IconButton(tooltip:'Saqlash',onPressed:()async{setState((){saved.contains(e['id'])?saved.remove(e['id']):saved.add(e['id'] as int);});await persist();},icon:Icon(saved.contains(e['id'])?Icons.bookmark:Icons.bookmark_border))])])));}))]);
  }
  Widget sourcePage()=>Column(children:[Padding(padding:const EdgeInsets.all(20),child:FilledButton.icon(onPressed:addSource,icon:const Icon(Icons.add_link),label:const Text('Kanal havolasini qo‘shish'))),Expanded(child:sources.isEmpty?empty('Manbalar qo‘shilmagan','Ochiq kanal yoki guruh havolasini qo‘shing. Kirish imkoniyatini kuzatuvchi server tekshiradi.',Icons.rss_feed):ListView(children:sources.map((s)=>ListTile(leading:const Icon(Icons.campaign_outlined),title:Text('@${s['name']}'),subtitle:Text('${s['status']} • ${categories[s['filter']]??'Barchasi'}'),trailing:IconButton(tooltip:'O‘chirish',onPressed:()=>removeSource(s['name'] as String),icon:const Icon(Icons.delete_outline)))).toList()))]);
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('↗ havola'),actions:[IconButton(tooltip:'Yangilash',onPressed:busy?null:sync,icon:const Icon(Icons.sync))]),body:Column(children:[if(busy)const LinearProgressIndicator(),Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),child:Text(status,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white60,fontSize:12))),Expanded(child:tab==0?catalog():tab==1?sourcePage():SettingsPanel(url:url,token:token,sound:sound,voice:voice,onSound:(v)async{setState(()=>sound=v);await persist();},onVoice:(v)async{setState(()=>voice=v);await persist();},onSave:settingsSave,onTest:()async{try{final ok=await bridge.invokeMethod<bool>('permission')??false;if(!ok){toast('Bildirishnomaga ruxsat berilmadi. Telefon sozlamalarini tekshiring.');return;}await bridge.invokeMethod('testNotification',{'sound':sound});toast('Sinov bildirishnomasi yuborildi.');}on PlatformException catch(e){toast(e.message??'Bildirishnoma ishlamadi');}},onSpeak:()=>speech('Havola. Ovozli bildirishnoma yoqildi.'),onPermission:()async{try{final ok=await bridge.invokeMethod<bool>('permission');toast(ok==true?'Bildirishnomaga ruxsat bor.':'Bildirishnoma ruxsati berilmadi.');}on PlatformException catch(e){toast(e.message??'Ruxsatni tekshirib bo‘lmadi');}}))]),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.grid_view_outlined),label:'Katalog'),NavigationDestination(icon:Icon(Icons.rss_feed),label:'Manbalar'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Sozlamalar')]));
}
class SettingsPanel extends StatefulWidget{
  const SettingsPanel({super.key,required this.url,required this.token,required this.sound,required this.voice,required this.onSound,required this.onVoice,required this.onSave,required this.onTest,required this.onSpeak,required this.onPermission});
  final String url,token;final bool sound,voice;final ValueChanged<bool> onSound,onVoice;final Future<void> Function(TextEditingController,TextEditingController) onSave;final VoidCallback onTest,onSpeak,onPermission;
  @override State<SettingsPanel> createState()=>_SettingsPanelState();
}
class _SettingsPanelState extends State<SettingsPanel>{
  late final TextEditingController endpoint=TextEditingController(text:widget.url),secret=TextEditingController(text:widget.token);
  @override void dispose(){endpoint.dispose();secret.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[const Text('Bildirishnoma va ovoz',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),SwitchListTile(title:const Text('Bildirishnoma tovushi'),subtitle:const Text('Telefonning standart bildirishnoma signali'),value:widget.sound,onChanged:widget.onSound),SwitchListTile(title:const Text('Yangi e’lonni ovozda o‘qish'),subtitle:const Text('Ilova ochiq paytda; telefon TTS ovozi kerak'),value:widget.voice,onChanged:widget.onVoice),OutlinedButton(onPressed:widget.onPermission,child:const Text('Bildirishnoma ruxsatini so‘rash')),Wrap(spacing:12,children:[OutlinedButton(onPressed:widget.onTest,child:const Text('Signalni tekshirish')),OutlinedButton(onPressed:widget.onSpeak,child:const Text('Ovozni tekshirish'))]),const SizedBox(height:18),const Text('Android fon tekshiruvi taxminan 15 daqiqada bajariladi. Batareya cheklovlari uni kechiktirishi mumkin. Tovush va Bezovta qilmang rejimini telefon boshqaradi.',style:TextStyle(color:Colors.white60)),const Divider(height:32),const Text('Kuzatuvchi server',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),TextField(controller:endpoint,decoration:const InputDecoration(labelText:'HTTPS manzil',hintText:'https://server.uz',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:secret,obscureText:true,autocorrect:false,enableSuggestions:false,decoration:const InputDecoration(labelText:'Shaxsiy server kirish tokeni',border:OutlineInputBorder())),const SizedBox(height:12),FilledButton(onPressed:()=>widget.onSave(endpoint,secret),child:const Text('Saqlash va ulanish')),const SizedBox(height:24),const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.auto_awesome_outlined),title:Text('AI hali ulanmagan'),subtitle:Text('Hozir server kalit so‘zlar bilan saralaydi. OpenAI API kaliti ilova ichiga yozilmaydi.'))]);
}
