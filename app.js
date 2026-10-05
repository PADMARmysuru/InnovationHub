function $(id){return document.getElementById(id)}
function loadProjectList(){
 const box=$("projectList"); if(!box||typeof projects==="undefined") return;
 const filters=document.querySelectorAll(".filter");
 function render(filter="all"){
  box.innerHTML="";
  const groups=filter==="all"?["Mini","Major","Research"]:[filter];
  groups.forEach(type=>{
   const items=projects.filter(p=>p.type===type);
   if(!items.length)return;
   const sec=document.createElement("section"); sec.className="project-section"; sec.id=type.toLowerCase();
   sec.innerHTML=`<span class="eyebrow">${type.toUpperCase()} PROJECTS</span><h2>${type==="Mini"?"Innovative but syllabus-aligned":type==="Major"?"Integrated design, memory & testing":"Advanced investigation & research"}</h2>`;
   const grid=document.createElement("div");grid.className="project-grid";
   items.forEach(p=>{const c=document.createElement("article");c.className="project-card";c.innerHTML=`<span class="tag">${p.type}</span><h3>${p.title}</h3><p>${p.idea}</p><div class="topics"><strong>Topics:</strong> ${p.topics}</div>`;grid.appendChild(c)});
   sec.appendChild(grid);box.appendChild(sec);
  });
 }
 filters.forEach(b=>b.addEventListener("click",()=>{filters.forEach(x=>x.classList.remove("active"));b.classList.add("active");render(b.dataset.filter)}));
 render();
}
function loadDashboard(){
 if(!$("saveProject"))return;
 const key="dviProject", data=JSON.parse(localStorage.getItem(key)||"{}");
 ["studentName","usn","ptype","ptitle"].forEach(k=>{if(data[k])$(k).value=data[k]});
 function refresh(){
  const checked=[...document.querySelectorAll(".mile")].filter(x=>x.checked).length;
  const progress=Math.round(checked/6*100);
  $("dashTitle").textContent=$("ptitle").value||"Not selected";$("dashType").textContent=$("ptype").value;
  $("dashProgress").textContent=progress+"%";$("dashStatus").textContent=progress===100?"Completed":progress?"In progress":"Not started";
  localStorage.setItem(key,JSON.stringify({studentName:$("studentName").value,usn:$("usn").value,ptype:$("ptype").value,ptitle:$("ptitle").value,progress}));
 }
 $("saveProject").onclick=()=>{refresh();alert("Project details saved.");};
 document.querySelectorAll(".mile").forEach(x=>x.addEventListener("change",refresh));
 $("saveUpdate").onclick=()=>{const t=$("updateText").value.trim();if(!t)return;const arr=JSON.parse(localStorage.getItem("dviUpdates")||"[]");arr.unshift({text:t,date:new Date().toLocaleString()});localStorage.setItem("dviUpdates",JSON.stringify(arr));$("updateText").value="";showTimeline()};
 showTimeline();refresh();
 function showTimeline(){const box=$("timeline");if(!box)return;const arr=JSON.parse(localStorage.getItem("dviUpdates")||"[]");box.innerHTML=arr.map(x=>`<div class="timeline-item"><small>${x.date}</small><div>${x.text}</div></div>`).join("")}
}
function loadFaculty(){
 if(!$("totalProjects"))return;
 const d=JSON.parse(localStorage.getItem("dviProject")||"{}");const p=d.ptype||"";
 $("totalProjects").textContent=d.ptitle?1:0;$("miniCount").textContent=p==="Mini"?1:0;$("majorCount").textContent=p==="Major"?1:0;$("researchCount").textContent=p==="Research"?1:0;
 $("facultyProject").innerHTML=d.ptitle?`<p><strong>${d.ptitle}</strong></p><p>Student: ${d.studentName||"—"} · USN: ${d.usn||"—"} · Type: ${p}</p><p>Progress: <strong>${d.progress||0}%</strong></p>`:"<p>No student project has been registered in this prototype yet.</p>";
}
document.addEventListener("DOMContentLoaded",()=>{loadProjectList();loadDashboard();loadFaculty();});