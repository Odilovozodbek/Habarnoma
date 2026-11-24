const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=require('node:fs').mkdtempSync(require('node:path').join(require('node:os').tmpdir(),'habarnoma-test-'));const out=root;fs.mkdirSync(out,{recursive:true});
class Element{constructor(){this.value='';this.textContent='';this.children=[];this.checked=false;}
 replaceChildren(...x){this.children=x;}append(...x){this.children.push(...x);}after(){}setAttribute(){}removeAttribute(){} showModal(){} close(){} }
const elements=new Map();
global.document={getElementById(id){if(!elements.has(id))elements.set(id,new Element());return elements.get(id);},querySelectorAll:()=>[],createElement:()=>new Element(),createTextNode:s=>s,querySelector:()=>new Element()};
const exportsZip={};new Function('exports','module',fs.readFileSync(path.resolve(__dirname,'../vendor/zip-no-worker.min.js'),'utf8'))(exportsZip,{});global.zip=exportsZip;global.RESTORE_SOURCE=fs.readFileSync(path.resolve(__dirname,'../src/tiklash.py'),'utf8');global.FORM_TEMPLATE=fs.readFileSync(path.resolve(__dirname,'../src/form.html'),'utf8');
const source=fs.readFileSync(path.resolve(__dirname,'../src/app.js'),'utf8')+'\n'+fs.readFileSync(path.resolve(__dirname,'../src/workspace.js'),'utf8');
const test=`
(async()=>{
$('targetAI').value='Claude';model=newModel('Sinov');projects=[model];model.goal='Sinov maqsadi';model.next='Davom etish';$('budget').value='4';$('cap').value='0.1';$('focus').value='login';
model.links=[{id:'link1',title:'Gemini dizayn',url:'https://gemini.google.com/app/abc'}];
const old=newNote('Claude','old','ESKI_VERSIYA_123');old.archived=true;model.notes.push(old);
const open=async(file)=>{const blob=await fs.openAsBlob(file);Object.defineProperty(blob,'name',{value:path.basename(file)});return blob;};
const data=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures/inputs/chats.json')));
const active=chatCandidate(data[0]);assert(active.body.includes('Flutter login'));assert(!active.body.includes('old branch'));assert.equal(chatCandidate(data[1]).source,'Claude');
const tg=chatCandidate({name:'Jamoa',messages:[{type:'message',date:'2026',from:'A',text:['Qaror ',{type:'bold',text:'sinov'}]}]});assert(tg.body.includes('Qaror sinov'));
assert.equal(mergeNotes([active,tg,active]),2);assert.equal(mergeNotes([active]),0);
const raw=new Uint8Array(225123);for(let i=0;i<raw.length;i++)raw[i]=i%251;
const writer=new zip.ZipWriter(new zip.BlobWriter());
await writer.add('src/main.dart',new zip.TextReader('class HabarnomaApp {}'));
await writer.add('Library/cache.bin',new zip.TextReader('generated build cache'));
await writer.add('assets/design.bin',new zip.BlobReader(new Blob([raw])));
await writer.add('notes.txt',new zip.TextReader('notes'));
const archive=await writer.close();Object.defineProperty(archive,'name',{value:'Demo.zip'});
await addFiles([archive],false);assert.equal(entries.length,4);assert.equal(chosenEntries().length,2);
$('media').checked=true;$('applyFilter').onclick();assert.equal(chosenEntries().length,3);
await generateContext();assert(!contextText.includes('ESKI_VERSIYA_123'));assert(contextText.includes('gemini.google.com'));assert(contextText.includes('Claude uchun'));assert(contextText.includes('HabarnomaApp'));assert(contextText.includes('Flutter login'));assert(bytes(contextText)<=4000);
planParts();let n=plans.length;assert(n>=3);for(let i=0;i<n;i++){const b=await writePart(i);assert(b.size<=100000);fs.writeFileSync(path.join(out,'test-'+i+'.zip'),Buffer.from(await b.arrayBuffer()));}
fs.writeFileSync(path.join(out,'tiklash.py'),RESTORE_SOURCE);
const form=contributionForm({...model,name:'<script> test $&'});assert(form.includes('\\\\u003cscript> test $&'));assert(!form.includes('__PROJECT_DATA__'));
fs.writeFileSync(path.join(out,'form.html'),form);console.log('PASS active chat branch, Telegram, Claude, dedup, cap, content, generated/sensitive filter, oversized split archive, form generation; ZIP parts:',n);
const prior=model;const another=newModel('Second');projects.push(another);useProject(another);assert.equal(model.notes.length,0);assert.equal(entries.length,0);useProject(prior);assert.equal(entries.length,4);
const pieces=[];
for(let i=0;i<n;i++){const rr=new zip.ZipReader(new zip.BlobReader(new Blob([fs.readFileSync(path.join(out,'test-'+i+'.zip'))])));const ee=await rr.getEntries();const manifest=JSON.parse(await ee.find(x=>x.filename===manifestName).getData(new zip.TextWriter()));for(const m of manifest.files.filter(m=>m.path.endsWith('design.bin'))){pieces.push({offset:m.offset,blob:await ee.find(e=>e.filename===m.entry).getData(new zip.BlobWriter(),{checkSignature:true})});}await rr.close();}
const recovered=new Uint8Array(await new Blob(pieces.sort((a,b)=>a.offset-b.offset).map(p=>p.blob)).arrayBuffer());
const original=Buffer.from(raw);assert.deepEqual(Buffer.from(recovered),original);
assert.equal(validatedLinks([{url:'javascript:alert(1)'},{url:'https://user:pass@example.com'},{url:'https://chatgpt.com/c/test'}]).length,1);
console.log('PASS project isolation, valid source URLs and byte-for-byte reassembly');
})()`;
const run=new Function('fs','path','assert','root','out','__dirname',source.replace(/start\(\);\s*$/,'')+'\nreturn '+test.trimStart());run(fs,path,assert,root,out,__dirname).catch(e=>{console.error(e);process.exit(1);});
