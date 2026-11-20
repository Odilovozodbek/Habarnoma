import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const HavolaApp());
const bridge = MethodChannel('uz.havola/native');
const categories = <String, String>{'all':'Barchasi','dars':'Dars vaqtlari','tanlov':'Tanlovlar','tadbir':'Tadbirlar','hakaton':'Hakatonlar','universitet':'Universitet','musobaqa':'Musobaqalar','grant':'Grantlar','boshqa':'Boshqa'};
String? channelName(String value) => RegExp(r'^(?:https?://t\.me/|@)([A-Za-z][A-Za-z0-9_]{3,31})/?$').firstMatch(value.trim())?.group(1)?.toLowerCase();

class HavolaApp extends StatelessWidget {
  const HavolaApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner:false,title:'Habarnoma',theme:ThemeData(brightness:Brightness.dark,useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff67edb3),brightness:Brightness.dark),scaffoldBackgroundColor:const Color(0xff0b121c)),home:const Dashboard());
}
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  List<Map<String,dynamic>> events=[],sources=[];
  Set<int> saved={};
  String category='all',query='',status='Manba qo‘shing',url='',token='',musicName='Telefonning standart signali';
  bool sound=true,voice=false,busy=false,onlySaved=false;
  int tab=0;
  Timer? timer;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);load();timer=Timer.periodic(const Duration(seconds:60),(_){if(sources.isNotEmpty || url.isNotEmpty)sync();});}
  @override void dispose(){timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed && (sources.isNotEmpty || url.isNotEmpty))sync();}
  void toast(String message){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));}
  Future<void> load()async{
    try {
      final data=jsonDecode(await bridge.invokeMethod<String>('read')??'{}') as Map<String,dynamic>;
      url=data['url'] as String? ??'';token=data['token'] as String? ??'';
      sound=data['sound'] as bool? ??true;voice=data['voice'] as bool? ??false;
      category = categories.containsKey(data['category']) ? data['category'] as String : 'all';
      musicName = await bridge.invokeMethod<String>('musicName') ?? musicName;
      sources=await localSources();
      status=sources.isEmpty?'Manba qo‘shing':'Yangilanmoqda';
      saved=((data['saved'] as List?)??[]).map((e)=>(e as num).toInt()).toSet();
      final cache=await bridge.invokeMethod<String>('cached');
      if(cache!=null)events=(jsonDecode(cache) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
      if(mounted)setState((){});
      if(url.isNotEmpty || sources.isNotEmpty)await sync();
    }on MissingPluginException {toast('Bildirishnoma va ovoz Android qurilmada ishlaydi.');}
    catch(_){toast('Sozlamalarni yuklashda xato.');}
  }
  Future<void> persist()async{
    await bridge.invokeMethod('configure',{'json':jsonEncode({'url':url,'token':token,'sound':sound,'voice':voice,'saved':saved.toList(),'category':category})});
  }
  Future<List<Map<String,dynamic>>> localSources() async {
    final raw = await bridge.invokeMethod<String>('localSources') ?? '[]';
    return (jsonDecode(raw) as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
  }

  Future<void> sync() async {
    if(busy) return;
    setState(()=>busy=true);
    try {
      final raw = await bridge.invokeMethod<String>('sync');
      final list = await localSources();
      var message = 'Yangilandi';
      if(url.isNotEmpty) {
        try {
          final old = await bridge.invokeMethod<String>('api',{'path':'/sources','method':'GET'});
          list.addAll((jsonDecode(old ?? '[]') as List).map((v)=>Map<String,dynamic>.from(v as Map)));
        } on PlatformException { message = 'Shaxsiy server bilan aloqa yo‘q'; }
      }
      if (!mounted) return;
      setState(() {
        sources = list;
        events = (jsonDecode(raw ?? '[]') as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList().reversed.toList();
        status = list.isEmpty ? 'Manba qo‘shing' : list.any((v)=>v['status'].toString().startsWith('O‘qib'))
            ? 'Ayrim manbalarni o‘qib bo‘lmadi · Manbalarni tekshiring' : message;
      });
    } on PlatformException catch(e) { if(mounted)setState(()=>status=e.message ?? 'Ulanish xatosi'); }
    finally { if(mounted)setState(()=>busy=false); }
  }

  Future<void> addSource() async {
    String link='', type='all';
    final selected = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Manba qo‘shish'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(autofocus:true,keyboardType:TextInputType.url,onChanged:(s)=>link=s.trim(),
          decoration:const InputDecoration(labelText:'Sayt yoki Telegram havolasi',hintText:'https://… yoki @kanal')),
        const SizedBox(height:16),
        DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Qabul qilinadigan xabarlar'),
          items:categories.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),
          onChanged:(v)=>type=v ?? 'all'),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Bekor qilish')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Qo‘shish'))]));
    if(selected!=true || !mounted) return;
    try {
      await bridge.invokeMethod('addLocal',{'url':link,'filter':type});
      final local=await localSources();
      if(!mounted)return;
      setState(()=>sources=[...local,...sources.where((s)=>s['url']==null)]);
      await sync();
    } on PlatformException catch(e) {toast(e.message ?? 'Manba qo‘shilmadi');}
  }

  Future<void> removeSource(Map<String,dynamic> source) async {
    try {
      if(source['url']!=null) {
        await bridge.invokeMethod('removeLocal',{'url':source['url']});
      } else {
        await bridge.invokeMethod('api',{'path':'/sources/${source['name']}','method':'DELETE'});
      }
      await sync();
    } on PlatformException catch(e) {toast(e.message ?? 'Manba o‘chirilmadi');}
  }

  Future<void> chooseMusic(bool reset) async {
    try {
      if(reset) await bridge.invokeMethod('resetMusic');
      else if(await bridge.invokeMethod<String>('pickMusic')==null) return;
      final label=await bridge.invokeMethod<String>('musicName');
      if(mounted && label!=null)setState(()=>musicName=label);
    } on PlatformException catch(e) {toast(e.message ?? 'Musiqani tanlab bo‘lmadi');}
  }
  Future<void> settingsSave(TextEditingController endpoint,TextEditingController secret)async{
    final next=endpoint.text.trim().replaceAll(RegExp(r'/+$'),'');
    final uri=Uri.tryParse(next);
    if(next.isNotEmpty&&(uri==null||uri.scheme!='https'||uri.host.isEmpty||uri.userInfo.isNotEmpty||uri.hasQuery||uri.hasFragment||uri.path.isNotEmpty)){toast('Faqat HTTPS server manzilini kiriting, masalan https://server.uz');return;}
    if(next.isNotEmpty&&secret.text.trim().isEmpty){toast('Server kirish tokenini kiriting.');return;}
    setState((){url=next;token=secret.text.trim();if(next.isEmpty){events=[];sources=[];status='Manba qo‘shing';}});
    try{await persist();if(url.isNotEmpty || sources.isNotEmpty)await sync();toast('Sozlamalar saqlandi.');}on PlatformException catch(e){toast(e.message??'Saqlanmadi');}
  }
  Future<void> speech(String text)async{try{await bridge.invokeMethod('speak',{'text':text});}on PlatformException catch(e){toast(e.message??'Ovoz ishlamadi');}}
  Widget empty(String title,String subtitle,IconData icon)=>Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:58,color:const Color(0xff67edb3)),const SizedBox(height:20),Text(title,style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),const SizedBox(height:10),Text(subtitle,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60,height:1.5))])));
  Widget catalog(){
    final rows=events.where((e)=>(category=='all'||e['category']==category)&&(!onlySaved||saved.contains(e['id']))&&e['text'].toString().toLowerCase().contains(query.toLowerCase())).toList();
    return Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,8,16,0),child:TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'E’lon qidirish',border:OutlineInputBorder()))),SizedBox(height:66,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(12),children:categories.entries.map((e)=>Padding(padding:const EdgeInsets.only(right:8),child:ChoiceChip(label:Text(e.value),selected:category==e.key,onSelected:(_)async{setState(()=>category=e.key);await persist();}))).toList())),SwitchListTile(dense:true,title:Text('${rows.length} ta e’lon'),subtitle:const Text('Faqat saqlanganlar'),value:onlySaved,onChanged:(v)=>setState(()=>onlySaved=v)),Expanded(child:rows.isEmpty?empty('Hali e’lon yo‘q',url.isEmpty?'Manbalar bo‘limida sayt yoki ochiq Telegram kanalini qo‘shing.':'Tanlangan bo‘limda yangi e’lon hali kelmagan.',Icons.inbox_outlined):ListView.builder(itemCount:rows.length,itemBuilder:(ctx,i){final e=rows[i];return Card(margin:const EdgeInsets.fromLTRB(16,0,16,12),child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(categories[e['category']]??'E’lon',style:const TextStyle(color:Color(0xff67edb3))),const SizedBox(height:12),if((e['schedule'] ?? '').toString().isNotEmpty) Padding(padding:const EdgeInsets.only(bottom:8),child:Text('◷  ${e['schedule']}',style:const TextStyle(color:Color(0xffffd176),fontWeight:FontWeight.w600))),Text((e['summary'] ?? e['text']).toString(),maxLines:8,overflow:TextOverflow.ellipsis),const SizedBox(height:14),Text('${e['source']}',style:const TextStyle(color:Colors.white60)),Wrap(spacing:4,children:[TextButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Asl e’lon'),content:SingleChildScrollView(child:SelectableText('${e['text']}\n\n${e['url']}')),actions:[TextButton(onPressed:()async{try{await bridge.invokeMethod('openPost',{'url':e['url']});}on PlatformException catch(err){toast(err.message ?? 'Havola ochilmadi');}},child:const Text('Manbani ochish')),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Yopish'))])),icon:const Icon(Icons.article_outlined),label:const Text('Batafsil')),IconButton(tooltip:'Ovozda o‘qish',onPressed:()=>speech((e['summary'] ?? e['text']).toString()),icon:const Icon(Icons.volume_up_outlined)),IconButton(tooltip:'Saqlash',onPressed:()async{setState((){saved.contains(e['id'])?saved.remove(e['id']):saved.add(e['id'] as int);});await persist();},icon:Icon(saved.contains(e['id'])?Icons.bookmark:Icons.bookmark_border))])])));}))]);
  }
  Widget sourcePage()=>Column(children:[Padding(padding:const EdgeInsets.all(20),child:FilledButton.icon(onPressed:busy?null:addSource,icon:const Icon(Icons.add_link),label:const Text('Sayt yoki Telegram qo‘shish'))),Expanded(child:sources.isEmpty?empty('Manbalar qo‘shilmagan','Sayt, RSS yoki ochiq Telegram kanalining havolasini kiriting.',Icons.rss_feed):ListView(children:sources.map((s)=>ListTile(leading:const Icon(Icons.campaign_outlined),title:Text('${s['name']}'),subtitle:Text('${s['status']} • ${categories[s['filter']]??'Barchasi'}'),trailing:IconButton(tooltip:'O‘chirish',onPressed:busy?null:()=>removeSource(s),icon:const Icon(Icons.delete_outline)))).toList()))]);
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Habarnoma'),actions:[IconButton(tooltip:'Yangilash',onPressed:busy?null:sync,icon:const Icon(Icons.sync))]),body:Column(children:[if(busy)const LinearProgressIndicator(),Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),child:Text(status,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white60,fontSize:12))),Expanded(child:tab==0?catalog():tab==1?sourcePage():SettingsPanel(musicName:musicName,chooseMusic:chooseMusic,url:url,token:token,sound:sound,voice:voice,onSound:(v)async{setState(()=>sound=v);await persist();},onVoice:(v)async{setState(()=>voice=v);await persist();},onSave:settingsSave,onTest:()async{try{final ok=await bridge.invokeMethod<bool>('permission')??false;if(!ok){toast('Bildirishnomaga ruxsat berilmadi. Telefon sozlamalarini tekshiring.');return;}await bridge.invokeMethod('testNotification',{'sound':sound});toast('Sinov bildirishnomasi yuborildi.');}on PlatformException catch(e){toast(e.message??'Bildirishnoma ishlamadi');}},onSpeak:()=>speech('Havola. Ovozli bildirishnoma yoqildi.'),onPermission:()async{try{final ok=await bridge.invokeMethod<bool>('permission');toast(ok==true?'Bildirishnomaga ruxsat bor.':'Bildirishnoma ruxsati berilmadi.');}on PlatformException catch(e){toast(e.message??'Ruxsatni tekshirib bo‘lmadi');}}))]),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[NavigationDestination(icon:Icon(Icons.grid_view_outlined),label:'Katalog'),NavigationDestination(icon:Icon(Icons.rss_feed),label:'Manbalar'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Sozlamalar')]));
}
class SettingsPanel extends StatefulWidget{
  const SettingsPanel({super.key,required this.musicName,required this.chooseMusic,required this.url,required this.token,required this.sound,required this.voice,required this.onSound,required this.onVoice,required this.onSave,required this.onTest,required this.onSpeak,required this.onPermission});
  final String musicName; final Future<void> Function(bool) chooseMusic;
  final String url,token;final bool sound,voice;final ValueChanged<bool> onSound,onVoice;final Future<void> Function(TextEditingController,TextEditingController) onSave;final VoidCallback onTest,onSpeak,onPermission;
  @override State<SettingsPanel> createState()=>_SettingsPanelState();
}
class _SettingsPanelState extends State<SettingsPanel>{
  late final TextEditingController endpoint=TextEditingController(text:widget.url),secret=TextEditingController(text:widget.token);
  @override void dispose(){endpoint.dispose();secret.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[const Text('Bildirishnoma va ovoz',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),SwitchListTile(title:const Text('Bildirishnoma tovushi'),subtitle:Text(widget.musicName),value:widget.sound,onChanged:widget.onSound),Wrap(children:[TextButton.icon(onPressed:()=>widget.chooseMusic(false),icon:const Icon(Icons.library_music_outlined),label:const Text('Musiqa tanlash')),TextButton(onPressed:()=>widget.chooseMusic(true),child:const Text('Standart signal'))]),SwitchListTile(title:const Text('Yangi e’lonni ovozda o‘qish'),subtitle:const Text('Ilova ochiq paytda; telefon TTS ovozi kerak'),value:widget.voice,onChanged:widget.onVoice),OutlinedButton(onPressed:widget.onPermission,child:const Text('Bildirishnoma ruxsatini so‘rash')),Wrap(spacing:12,children:[OutlinedButton(onPressed:widget.onTest,child:const Text('Signalni tekshirish')),OutlinedButton(onPressed:widget.onSpeak,child:const Text('Ovozni tekshirish'))]),const SizedBox(height:18),const Text('Android fon tekshiruvi taxminan 15 daqiqada bajariladi. Batareya cheklovlari uni kechiktirishi mumkin. Tovush va Bezovta qilmang rejimini telefon boshqaradi.',style:TextStyle(color:Colors.white60)),const Divider(height:32),const Text('Shaxsiy server (ixtiyoriy)',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),TextField(controller:endpoint,decoration:const InputDecoration(labelText:'HTTPS manzil',hintText:'https://server.uz',border:OutlineInputBorder())),const SizedBox(height:12),TextField(controller:secret,obscureText:true,autocorrect:false,enableSuggestions:false,decoration:const InputDecoration(labelText:'Shaxsiy server kirish tokeni',border:OutlineInputBorder())),const SizedBox(height:12),FilledButton(onPressed:()=>widget.onSave(endpoint,secret),child:const Text('Saqlash va ulanish')),const SizedBox(height:24),const ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.auto_awesome_outlined),title:Text('Xabarlar xulosasi'),subtitle:Text('Mavzu, sana va vaqt asl matndan ajratiladi. Batafsil tugmasi to‘liq matnni ko‘rsatadi.'))]);
}
