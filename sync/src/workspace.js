/* Shared project context and source provenance. Data stays in this browser. */
const noteKinds = {note:'Ish qaydi',decision:'Qaror',done:'Bajarildi',issue:'Ochiq masala',code:'Kod yoki dizayn'};
function validatedLinks(items) {
  if (!Array.isArray(items)) return [];
  const links=[];
  for (const item of items) {
    try {
      const url=new URL(item.url);
      if(url.protocol!=='https:' || url.username || url.password) continue;
      links.push({id:clean(item.id,80)||uid(),title:clean(item.title,140)||url.hostname,url:url.href});
    } catch {}
  }
  return links;
}
function mergeLinks(items) {
  model.links=validatedLinks(model.links);
  for(const link of validatedLinks(items)) {
    if(!model.links.some(x=>x.id===link.id || x.url===link.url)) model.links.push(link);
  }
  drawLinks();
}
function drawLinks() {
  model.links=validatedLinks(model.links);
  const selected=$('noteLink').value;
  const empty=make('option','Mustaqil yozuv');empty.value='';
  $('noteLink').replaceChildren(empty,...model.links.map(l=>{
    const opt=make('option',l.title);opt.value=l.id;return opt;
  }));
  if(model.links.some(l=>l.id===selected))$('noteLink').value=selected;
  $('sourceLinks').replaceChildren(...model.links.map(link=>{
    const li=make('li'),info=make('div'),anchor=make('a',link.title);
    anchor.href=link.url;anchor.target='_blank';anchor.rel='noopener noreferrer';
    const count=model.notes.filter(n=>n.linkId===link.id && !n.archived).length;
    info.append(anchor,make('div',new URL(link.url).hostname+' · '+count+' ta faol yozuv','small'));
    const use=make('button','Yozuv bog‘lash');
    use.onclick=()=>{$('noteLink').value=link.id;$('note').focus();};
    li.append(info,use);return li;
  }));
}
$('addLink').onclick=()=>{
  const links=validatedLinks([{title:$('linkTitle').value,url:$('linkUrl').value.trim()}]);
  if(!links.length){tell('To‘liq HTTPS havolasini kiriting.');return;}
  if((model.links||[]).some(l=>l.url===links[0].url)){tell('Bu manba avval qo‘shilgan.');return;}
  model.links.push(links[0]);saveProject();drawLinks();invalidate();
  $('linkTitle').value='';$('linkUrl').value='';
};
$('targetAI').onchange=()=>{contextText='';$('contextResult').hidden=true;};
const archivedButton=make('button','Oldingi versiyalar');
$('moreNotes').after(archivedButton);
archivedButton.onclick=()=>{
  const old=model.notes.filter(n=>n.archived);
  const list=make('div');
  if(!old.length)list.append(make('p','Hozircha eski deb belgilangan yozuv yo‘q.'));
  for(const n of old) {
    const item=make('div'),restore=make('button','Faollashtirish');
    item.append(make('h3',n.source+' · '+n.title),make('pre',n.body.slice(0,10000)),restore);
    restore.onclick=()=>{n.archived=false;saveProject();invalidate();drawNotes();$('dialog').close();};
    list.append(item);
  }
  dialog('Oldingi versiyalar',[list],null,null);
};
start();
