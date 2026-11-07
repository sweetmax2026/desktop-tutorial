const $ = id => document.getElementById(id);
let offset = 0;
const message = text => { $('message').textContent = text; };
function loggedIn(value) { $('login').hidden = value; $('inbox').hidden = !value; $('logout').hidden = !value; if (!value) $('rows').replaceChildren(); }
async function api(path, method = 'GET', data) {
  const response = await fetch(path, { method, credentials:'same-origin', headers: data ? {'Content-Type':'application/json'} : {}, body: data ? JSON.stringify(data) : undefined });
  const result = await response.json();
  if (!response.ok) { if (response.status === 401) loggedIn(false); throw Error(result.error || '请求失败'); }
  return result;
}
function text(tag, value, className) { const el = document.createElement(tag); el.textContent = value; if (className) el.className = className; return el; }
async function load() {
  try {
    const result = await api('/api/admin/feedback?offset=' + offset);
    loggedIn(true); $('rows').replaceChildren();
    if (!result.rows.length) $('rows').append(text('p', '暂无反馈。', 'muted'));
    for (const row of result.rows) {
      const card = document.createElement('article');
      card.append(text('h3', (row.status === 'done' ? '已处理' : '待处理') + ' · ' + row.category + ' · ' + new Date(row.createdAt).toLocaleString()), text('pre', row.content));
      card.append(text('p', '联系方式：' + (row.contact || '未填写'), 'meta'), text('p', '应用：' + (row.appVersion || '未附上') + ' / macOS：' + (row.systemVersion || '未附上'), 'meta'), text('p', '反馈编号：' + row.id, 'meta'));
      const actions = text('div', '', 'actions');
      for (const remove of [false,true]) {
        const button = text('button', remove ? '删除反馈' : row.status === 'done' ? '标记为待处理' : '标记为已处理', remove ? 'danger' : '');
        button.addEventListener('click', async () => {
          if (remove && !confirm('永久删除这条反馈？此操作无法撤销。')) return;
          button.disabled = true;
          try { await api('/api/admin/feedback/' + row.id, remove ? 'DELETE' : 'PATCH', remove ? undefined : {status:row.status === 'done' ? 'new' : 'done'}); await load(); message(remove ? '反馈已删除。' : '状态已更新。'); } catch(e) { message(e.message); button.disabled = false; }
        }); actions.append(button);
      }
      card.append(actions); $('rows').append(card);
    }
    $('previous').disabled = offset === 0; $('next').disabled = !result.hasMore; $('page').textContent = '第 ' + (offset / 50 + 1) + ' 页';
  } catch(e) { message(e.message); }
}
$('login').addEventListener('submit', async event => {
  event.preventDefault(); const button = event.currentTarget.querySelector('button'); button.disabled = true;
  try { await api('/api/admin/login', 'POST', {password:$('password').value}); $('password').value = ''; offset = 0; message(''); await load(); } catch(e) { message(e.message); } finally { button.disabled = false; }
});
$('logout').addEventListener('click', async () => { try { await api('/api/admin/logout','POST'); loggedIn(false); message('已退出。'); } catch(e) { message(e.message); } });
$('refresh').addEventListener('click', () => { message(''); load(); });
$('previous').addEventListener('click', () => { offset = Math.max(0, offset - 50); load(); });
$('next').addEventListener('click', () => { offset += 50; load(); });
load();
