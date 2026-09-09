// Review-only simulation. No storage, network, production data or real backup operations.
const params = new URLSearchParams(location.search);
if (params.has('clean')) document.documentElement.classList.add('clean');
if (params.get('theme') === 'dark') document.documentElement.dataset.theme = 'dark';
let state = params.get('state') || 'idle';
let hasBackup = state !== 'empty';
let timer;
let toastTimer;
const $ = id => document.getElementById(id);
const cloud = '<svg class="cloud-icon" viewBox="0 0 40 40" aria-hidden="true"><path d="M12 30H9a7 7 0 0 1-1-14 12 12 0 0 1 23-2 8 8 0 0 1 0 16h-3M20 35V19m-5 5 5-5 5 5"/></svg>';
const arrow = '<svg class="arrow" viewBox="0 0 24 24" aria-hidden="true"><path d="m9 5 7 7-7 7"/></svg>';
const history = () => `<section class="history" aria-labelledby="history-title"><div class="section-head"><h2 id="history-title">可恢复的备份</h2><span>保留最近 3 份</span></div>${hasBackup ? `<button class="snapshot" data-action="detail"><span><span class="date">9 月 9 日 <span>14:32</span></span><span class="meta">iPhone · 45.1 MB</span></span>${arrow}</button>` : `<div class="empty"><p>还没有云端备份</p><p>备份后，可以在这里恢复资料。</p></div>`}</section>`;
const info = () => `<details class="info"><summary>备份包含哪些内容</summary><p>已保存的角色资料、设定历史、立绘和资产原文件。备份不会自动同步之后的修改。</p></details>`;
const status = (title, message, actions='', running=true) => `<section class="status" role="status" aria-live="polite"><div class="status-title">${title}</div><p>${message}</p>${running ? '<div class="indeterminate" role="progressbar" aria-label="正在处理，进度暂不可测"></div>' : ''}${actions ? `<div class="status-actions">${actions}</div>` : ''}</section>`;
const button = (action, label) => `<button class="text-button" data-action="${action}">${label}</button>`;
function showToast(message) {
  clearTimeout(toastTimer); $('toast').textContent = message; $('toast').hidden = false;
  toastTimer = setTimeout(() => $('toast').hidden = true, 4500);
}
function render(next=state) {
  state = next; clearTimeout(timer);
  const detail = ['detail','download','ready','activating','stalled'].includes(state);
  $('page-title').textContent = detail ? '备份详情' : '备份与恢复';
  $('back').setAttribute('aria-label', detail ? '返回备份与恢复' : '返回设置');
  $('back').disabled = ['activating','stalled'].includes(state);
  $('refresh').hidden = detail;
  $('refresh').disabled = ['backup','waiting'].includes(state);
  $('scenario').value = [...$('scenario').options].some(o=>o.value===state) ? state : 'detail';
  const themeIsDark = document.documentElement.dataset.theme === 'dark';
  $('theme-toggle').setAttribute('aria-pressed', String(themeIsDark));
  $('theme-toggle').textContent = themeIsDark ? '浅色预览' : '深色预览';
  if (detail) {
    const detailHead = `<section class="detail-head"><h2>9 月 9 日 14:32</h2><p>2026 年 · 来自 iPhone</p></section><div class="facts" aria-label="备份概要"><span>2 个角色</span><span>5 个文件</span><span>45.1 MB</span></div><details class="detail-content"><summary>查看备份内容</summary><dl><div><dt>角色资料</dt><dd>2 个角色</dd></div><div><dt>设定历史</dt><dd>1 条记录</dd></div><div><dt>资产</dt><dd>3 项</dd></div><div><dt>原文件</dt><dd>5 个</dd></div></dl><p>目录记录的是这份备份保存时的内容。</p></details>`;
    let action = `<p class="detail-note">下载并检查后，再由你确认替换本机资料。</p><button class="primary" data-action="download">恢复这份备份</button>`;
    if (state === 'download') action = status('正在下载并检查','检查完成前，本机资料不会被替换。',button('detail','取消'));
    if (state === 'ready') action = status('备份已通过检查','确认后将替换本机现有资料。',button('confirm','继续恢复'),false);
    if (state === 'activating') action = status('正在恢复资料','请保持 App 打开，完成后即可使用。');
    if (state === 'stalled') action = status('恢复耗时较长','正在完成本机资料替换，请保持 App 打开。',`<details><summary>查看当前状态</summary><p>当前步骤：启用恢复后的资料。正在完成本机资料替换，完成后会自动返回。</p></details>`);
    $('main').innerHTML = detailHead + action;
    if (state === 'download') timer = setTimeout(() => {render('ready'); openConfirm();}, 2200);
    if (state === 'activating') timer = setTimeout(() => {render('idle'); showToast('资料已恢复');}, 2200);
  } else {
    const intro = `<section class="intro">${cloud}<h2>备份到 iCloud</h2><p>留一份已保存的角色资料与原文件。</p></section>`;
    let action = '<button class="primary" data-action="backup">立即备份</button>';
    if (state === 'backup') action = status('正在备份','正在准备并上传文件。',button('cancel','取消备份'));
    if (state === 'waiting') action = status('正在确认云端备份','文件已提交，等待 iCloud 确认完成。');
    if (state === 'failure') action = status('这次备份未完成','已有的云端备份仍可使用。',button('reason','查看原因')+button('backup','重试备份'),false);
    if (state === 'offline') action = status('暂时无法连接 iCloud','请检查 iCloud 账户和网络连接。',button('reconnect','重新检查'),false);
    if (state === 'recovery') action = status('本机资料暂时无法打开','可以选择一份云端备份恢复。',button('local-reason','查看原因'),false);
    let list = history();
    if (state === 'offline') list = `<section class="history"><div class="section-head"><h2>可恢复的备份</h2></div><div class="empty"><p>暂时无法读取备份列表</p><p>连接恢复后可重新查看。</p></div></section>`;
    $('main').innerHTML = intro + action + list + info();
    if (state === 'backup') timer = setTimeout(() => render('waiting'), 3500);
    if (state === 'waiting') timer = setTimeout(() => {hasBackup=true;render('idle');showToast('备份已完成');}, 3500);
  }
}
function openConfirm() { if (!$('confirm').open) $('confirm').showModal(); }
$('main').addEventListener('click', event => {
  const action = event.target.closest('[data-action]')?.dataset.action;
  if (!action) return;
  if (action === 'cancel') {render(hasBackup?'idle':'empty');showToast('已取消备份');}
  else if (action === 'reason') showToast('演示原因：上传中断，请检查网络后重试');
  else if (action === 'local-reason') showToast('演示原因：本机数据库无法打开');
  else if (action === 'reconnect') {render('idle');showToast('已重新读取 iCloud 状态（演示）');}
  else if (action === 'confirm') openConfirm();
  else render(action);
});
$('scenario').addEventListener('change', event => {
  $('confirm').close(); $('toast').hidden=true; hasBackup=event.target.value!=='empty';
  render(event.target.value); if(state==='ready') openConfirm();
});
$('theme-toggle').addEventListener('click', () => {
  document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'; render();
});
$('back').addEventListener('click', () => {
  if (['detail','ready'].includes(state)) render('idle');
  else if (state==='download') showToast('原型：下载检查可继续，返回不会确认恢复');
  else showToast('原型范围仅含备份与恢复，实际 App 返回设置');
});
$('refresh').addEventListener('click', () => showToast('已刷新云端备份（演示）'));
$('activate').addEventListener('click', () => {$('confirm').close(); render('activating');});
$('confirm').addEventListener('keydown', event => {
  if (event.key !== 'Tab') return;
  const controls = [...$('confirm').querySelectorAll('button:not(:disabled)')];
  const first = controls[0], last = controls[controls.length - 1];
  if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
  else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
});
$('confirm').addEventListener('close', () => {
  if (state === 'ready') document.querySelector('[data-action="confirm"]')?.focus({preventScroll:true});
});
$('confirm').addEventListener('click', event => {
  const rect = $('confirm').getBoundingClientRect();
  if (event.target === $('confirm') && (event.clientX<rect.left || event.clientX>rect.right || event.clientY<rect.top || event.clientY>rect.bottom)) $('confirm').close();
});
window.prototype = {render, openConfirm, getState:()=>state};
render(); if(state==='ready') openConfirm();
