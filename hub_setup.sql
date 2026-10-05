-- =====================================================================
--  Digital-VLSI Innovation Hub - Supabase setup
--  Run in Supabase -> SQL Editor, in the SAME project as Digital Design Explorer,
--  AFTER Explorer's progress-setup.sql and progress-teacher-auth.sql.
--
--  * Students log in with their Explorer account (USN + email + password).
--    The Hub uses Explorer's STUDENTS table and login sessions READ-ONLY.
--  * Faculty log in with their Explorer Teacher Login account.
--  * Only new tables/functions starting with "hub_" are created.
--    Nothing in Explorer is changed.
--  * Safe to run again.
-- =====================================================================

-- ---------- 0. Remove objects from the earlier Hub draft (if it was ever run) ----------
do $$ begin
  if to_regclass('public.hub_profiles') is not null then
    drop table if exists public.hub_certificates, public.hub_updates, public.hub_members,
                         public.hub_teams, public.hub_profiles, public.hub_faculty cascade;
  end if;
end $$;
drop function if exists public.hub_is_faculty(), public.hub_my_team_id(), public.hub_leader_team(),
  public.hub_taken_projects(), public.hub_save_profile(text,text,int,text), public.hub_my_state(),
  public.hub_create_team(text), public.hub_invite(text), public.hub_respond_invite(bigint,boolean),
  public.hub_remove_member(uuid), public.hub_leave_team(), public.hub_disband_team(),
  public.hub_select_project(text), public.hub_release_project(), public.hub_submit_proposal(text),
  public.hub_set_milestone(int,boolean), public.hub_add_update(text),
  public.hub_faculty_teams(), public.hub_faculty_action(bigint,text,text);

-- ---------- 1. Tables ----------
create table if not exists public.hub_projects (
  title text primary key,
  type  text not null check (type in ('Mini','Major','Research'))
);

create table if not exists public.hub_teams (
  id             bigint generated always as identity primary key,
  name           text not null check (length(trim(name)) between 2 and 60),
  leader_id      uuid not null references public."STUDENTS"(id) on delete cascade,
  semester       int  not null,
  section        text not null,
  project_title  text unique references public.hub_projects(title),   -- ONE team per project
  innovation     text,
  status         text not null default 'Forming' check (status in
                 ('Forming','Selected','Pending Approval','Changes Required',
                  'Approved','Ready for Final Review','Completed')),
  milestones     boolean[] not null default array[false,false,false,false,false,false,false],
  progress       int not null default 0,
  faculty_remark text,
  completed_on   date,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.hub_members (
  team_id    bigint not null references public.hub_teams(id) on delete cascade,
  student_id uuid   not null references public."STUDENTS"(id) on delete cascade,
  role       text   not null default 'member' check (role in ('leader','member')),
  status     text   not null default 'invited' check (status in ('invited','accepted')),
  created_at timestamptz not null default now(),
  primary key (team_id, student_id)
);
create unique index if not exists hub_one_team_per_student
  on public.hub_members(student_id) where status = 'accepted';

create table if not exists public.hub_updates (
  id         bigint generated always as identity primary key,
  team_id    bigint not null references public.hub_teams(id) on delete cascade,
  author_id  uuid   references public."STUDENTS"(id) on delete set null,
  body       text   not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table if not exists public.hub_certificates (
  cert_id       text primary key,
  team_id       bigint references public.hub_teams(id) on delete set null,
  student_id    uuid references public."STUDENTS"(id) on delete set null,
  student_name  text not null,
  usn           text not null,
  team_name     text not null,
  project_title text not null,
  project_type  text not null,
  issued_on     date not null default current_date
);

-- ---------- 2. Project catalogue (must match js/data.js) ----------
-- removes old titles no team is using, then (re)inserts the current list
delete from public.hub_projects p where not exists (select 1 from public.hub_teams t where t.project_title = p.title);
insert into public.hub_projects(title, type) values
  ('Digital Pattern Learning Circuit','Mini'),
  ('Adaptive Traffic Junction Controller','Mini'),
  ('Challenge–Response Digital Lock','Mini'),
  ('Adaptive Digital Resource Manager','Mini'),
  ('Debounced Keypad Scanner and Code Encoder','Mini'),
  ('Memory-Based Pattern Detector','Mini'),
  ('Reconfigurable Combinational Logic Unit','Mini'),
  ('Adaptive Arithmetic Processing Unit','Mini'),
  ('Dynamic Code Conversion Engine','Mini'),
  ('Intelligent Comparator System','Mini'),
  ('Self-Recovering FSM','Mini'),
  ('Multi-Mode Washing Machine Controller','Mini'),
  ('Serial Data Receiver with Frame Check','Mini'),
  ('Four-Floor Elevator Request Controller','Mini'),
  ('Configurable Register-Based Data Router','Mini'),
  ('Multi-Product Vending Controller with Change Return','Mini'),
  ('Tamper Sequence Detector','Mini'),
  ('Smart Memory Access Controller','Major'),
  ('Digital Data Integrity Monitor','Major'),
  ('Watchdog-Monitored Digital Controller','Major'),
  ('Digital Test Pattern Generator','Major'),
  ('Memory Testing Controller','Major'),
  ('Built-In Self-Test Digital Module','Major'),
  ('Address-Based Data Routing System','Major'),
  ('Configurable Register File','Major'),
  ('Memory-Based Decision Engine','Major'),
  ('Intelligent FIFO Controller','Major'),
  ('Multi-Bank Memory Controller','Major'),
  ('Address Error Detection System','Major'),
  ('Memory Protection Controller','Major'),
  ('Multi-Precision Arithmetic Unit','Major'),
  ('Saturating Arithmetic Unit','Major'),
  ('Overflow and Underflow Detection Unit','Major'),
  ('Triple Modular Redundancy (TMR) FSM','Major'),
  ('Logic Circuit Self-Diagnosis System','Major'),
  ('Test Coverage Monitor','Major'),
  ('Signature-Based Verification System','Major'),
  ('Branch Predictor Comparison Study','Research'),
  ('RISC-V Single-Cycle Processor Core','Research'),
  ('Systolic Array Accelerator for Matrix Multiplication','Research'),
  ('Cache Organization and Replacement Policy Study','Research'),
  ('Five-Stage Pipelined Processor with Hazard Unit','Research'),
  ('Clock-Gating Low-Power Design Study','Research'),
  ('AI-Assisted RTL Verification','Research'),
  ('Hardware Trojan Detection','Research'),
  ('FPGA Implementation of a Digital FIR Filter','Research')
on conflict (title) do update set type = excluded.type;

-- ---------- 3. Security: the browser cannot read or write these tables directly ----------
alter table public.hub_projects     enable row level security;
alter table public.hub_teams        enable row level security;
alter table public.hub_members      enable row level security;
alter table public.hub_updates      enable row level security;
alter table public.hub_certificates enable row level security;
revoke all on table public.hub_projects, public.hub_teams, public.hub_members,
                    public.hub_updates, public.hub_certificates from anon, authenticated;

-- ---------- 4. Internal helpers (not callable from the website) ----------
-- Explorer stores semester and section as free text ("5", "5th", "V", "sec a").
create or replace function public.hub_norm_sem(p text) returns int
language plpgsql immutable as $$
declare s text := upper(trim(coalesce(p,''))); d text;
begin
  d := substring(s from '[1-8]');
  if d is not null then return d::int; end if;
  s := regexp_replace(s, '(SEM(ESTER)?|[^A-Z])', '', 'g');
  return case s when 'I' then 1 when 'II' then 2 when 'III' then 3 when 'IV' then 4
                when 'V' then 5 when 'VI' then 6 when 'VII' then 7 when 'VIII' then 8
                when 'FIRST' then 1 when 'SECOND' then 2 when 'THIRD' then 3 when 'FOURTH' then 4
                when 'FIFTH' then 5 when 'SIXTH' then 6 when 'SEVENTH' then 7 when 'EIGHTH' then 8 else null end;
end $$;

create or replace function public.hub_norm_sec(p text) returns text
language sql immutable as $$
  select nullif(regexp_replace(regexp_replace(upper(trim(coalesce(p,''))), '^(SECTION|SEC)[^A-Z0-9]*', ''), '[^A-Z0-9]', '', 'g'), '');
$$;

-- Logged-in student from an Explorer session token (raises if not logged in)
create or replace function public.hub_student(p_token text) returns uuid
language plpgsql stable security definer set search_path = public, extensions as $$
declare v uuid := public.dde_session_student(p_token);
begin
  if v is null then raise exception 'Please log in again (your session has ended).'; end if;
  return v;
end $$;

create or replace function public.hub_require_teacher(p_token text) returns void
language plpgsql stable security definer set search_path = public, extensions as $$
begin
  if not coalesce(public.dde_session_is_teacher(p_token), false) then
    raise exception 'Faculty access only. Please log in with your Teacher Login.'; end if;
end $$;

create or replace function public.hub_team_of(p_student uuid) returns bigint
language sql stable security definer set search_path = public as $$
  select team_id from public.hub_members where student_id = p_student and status = 'accepted' limit 1;
$$;

-- team id if the student leads a team, else raises
create or replace function public.hub_led_team(p_student uuid) returns bigint
language plpgsql stable security definer set search_path = public as $$
declare v bigint;
begin
  select id into v from public.hub_teams where leader_id = p_student;
  if v is null then raise exception 'Only the team leader can do this.'; end if;
  return v;
end $$;

create or replace function public.hub_team_json(p_team bigint) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', t.id, 'name', t.name, 'semester', t.semester, 'section', t.section,
    'leader_id', t.leader_id, 'project_title', t.project_title,
    'project_type', pr.type, 'innovation', t.innovation, 'status', t.status,
    'milestones', to_jsonb(t.milestones), 'progress', t.progress,
    'faculty_remark', t.faculty_remark, 'completed_on', t.completed_on,
    'updated_at', t.updated_at,
    'members', coalesce((select jsonb_agg(jsonb_build_object(
        'id', s.id, 'name', s.student_name, 'usn', s.student_id,
        'role', m.role, 'status', m.status) order by m.role, s.student_id)
      from public.hub_members m join public."STUDENTS" s on s.id = m.student_id
      where m.team_id = t.id), '[]'::jsonb),
    'updates', coalesce((select jsonb_agg(jsonb_build_object(
        'author', coalesce(s.student_name, 'Former member'), 'body', u.body, 'at', u.created_at)
        order by u.created_at desc)
      from public.hub_updates u left join public."STUDENTS" s on s.id = u.author_id
      where u.team_id = t.id), '[]'::jsonb))
  from public.hub_teams t left join public.hub_projects pr on pr.title = t.project_title
  where t.id = p_team;
$$;

create or replace function public.hub_editable(p_team bigint) returns boolean
language sql stable security definer set search_path = public as $$
  select status in ('Forming','Selected','Changes Required') from public.hub_teams where id = p_team;
$$;

-- ---------- 5. Public functions (no login needed) ----------
create or replace function public.hub_taken_projects() returns table(project_title text)
language sql stable security definer set search_path = public as $$
  select project_title from public.hub_teams where project_title is not null;
$$;

create or replace function public.hub_verify_certificate(p_id text) returns jsonb
language sql stable security definer set search_path = public as $$
  select to_jsonb(c) - 'student_id' - 'team_id' from public.hub_certificates c
  where cert_id = upper(trim(p_id));
$$;

-- ---------- 6. Student functions (p_token = Explorer session token) ----------
create or replace function public.hub_my_state(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare me uuid := public.dde_session_student(p_token); v_team bigint;
begin
  if me is null then return null; end if;
  v_team := public.hub_team_of(me);
  return jsonb_build_object(
    'profile', (select jsonb_build_object('id', s.id, 'usn', s.student_id, 'name', s.student_name,
                  'semester_text', s.semester::text, 'section_text', s.section::text,
                  'semester', public.hub_norm_sem(s.semester::text), 'section', public.hub_norm_sec(s.section::text))
                from public."STUDENTS" s where s.id = me),
    'team', case when v_team is null then null else public.hub_team_json(v_team) end,
    'invites', coalesce((select jsonb_agg(jsonb_build_object(
        'team_id', t.id, 'team_name', t.name, 'leader', ls.student_name, 'leader_usn', ls.student_id))
      from public.hub_members m join public.hub_teams t on t.id = m.team_id
      join public."STUDENTS" ls on ls.id = t.leader_id
      where m.student_id = me and m.status = 'invited'), '[]'::jsonb),
    'certificates', coalesce((select jsonb_agg(jsonb_build_object(
        'cert_id', c.cert_id, 'project_title', c.project_title, 'issued_on', c.issued_on))
      from public.hub_certificates c where c.student_id = me), '[]'::jsonb));
end $$;

create or replace function public.hub_create_team(p_token text, p_name text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := public.hub_student(p_token); v_sem int; v_sec text; v bigint;
begin
  select public.hub_norm_sem(semester::text), public.hub_norm_sec(section::text) into v_sem, v_sec
    from public."STUDENTS" where id = me;
  if v_sem is null or v_sec is null then
    raise exception 'Your semester or section in Digital Design Explorer is missing or unclear. Ask your faculty to correct it.'; end if;
  if public.hub_team_of(me) is not null then raise exception 'You are already in a team.'; end if;
  insert into public.hub_teams(name, leader_id, semester, section) values (trim(p_name), me, v_sem, v_sec) returning id into v;
  insert into public.hub_members(team_id, student_id, role, status) values (v, me, 'leader', 'accepted');
  delete from public.hub_members where student_id = me and status = 'invited';
end $$;

create or replace function public.hub_invite(p_token text, p_usn text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := public.hub_student(p_token); v bigint := public.hub_led_team(me);
        t public.hub_teams; s public."STUDENTS";
begin
  select * into t from public.hub_teams where id = v;
  if not public.hub_editable(v) then raise exception 'Members can only be changed before faculty approval.'; end if;
  select * into s from public."STUDENTS" where upper(student_id) = upper(trim(coalesce(p_usn,'')));
  if s.id is null then raise exception 'This USN is not registered on Digital Design Explorer yet.'; end if;
  if public.hub_norm_sem(s.semester::text) is distinct from t.semester or public.hub_norm_sec(s.section::text) is distinct from t.section then
    raise exception 'Team members must be from the same semester and section (Semester %, Section %).', t.semester, t.section; end if;
  if public.hub_team_of(s.id) is not null then raise exception 'This student is already in a team.'; end if;
  if (select count(*) from public.hub_members where team_id = v) >= 4 then
    raise exception 'A team can have at most 4 members (including pending invites).'; end if;
  insert into public.hub_members(team_id, student_id) values (v, s.id) on conflict do nothing;
end $$;

create or replace function public.hub_respond_invite(p_token text, p_team bigint, p_accept boolean) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := public.hub_student(p_token);
begin
  if not exists (select 1 from public.hub_members where team_id = p_team and student_id = me and status = 'invited') then
    raise exception 'Invite not found.'; end if;
  if not p_accept then delete from public.hub_members where team_id = p_team and student_id = me; return; end if;
  if public.hub_team_of(me) is not null then raise exception 'You are already in a team.'; end if;
  if not exists (select 1 from public.hub_teams t join public."STUDENTS" s on s.id = me
                 where t.id = p_team and t.semester = public.hub_norm_sem(s.semester::text)
                   and t.section = public.hub_norm_sec(s.section::text)) then
    raise exception 'You can only join a team from your own semester and section.'; end if;
  if not public.hub_editable(p_team) then raise exception 'This team has already been approved and cannot take new members.'; end if;
  update public.hub_members set status = 'accepted' where team_id = p_team and student_id = me;
  delete from public.hub_members where student_id = me and status = 'invited';
end $$;

create or replace function public.hub_remove_member(p_token text, p_student uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare v bigint := public.hub_led_team(public.hub_student(p_token));
begin
  if not public.hub_editable(v) then raise exception 'Members can only be changed before faculty approval.'; end if;
  delete from public.hub_members where team_id = v and student_id = p_student and role <> 'leader';
end $$;

create or replace function public.hub_leave_team(p_token text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := public.hub_student(p_token); v bigint := public.hub_team_of(me);
begin
  if v is null then raise exception 'You are not in a team.'; end if;
  if (select leader_id from public.hub_teams where id = v) = me then raise exception 'The leader cannot leave. Disband the team instead.'; end if;
  if not public.hub_editable(v) then raise exception 'You cannot leave after faculty approval. Contact your faculty.'; end if;
  delete from public.hub_members where team_id = v and student_id = me;
end $$;

create or replace function public.hub_disband_team(p_token text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare v bigint := public.hub_led_team(public.hub_student(p_token));
begin
  if not public.hub_editable(v) then raise exception 'An approved team cannot be disbanded. Contact your faculty.'; end if;
  delete from public.hub_teams where id = v;
end $$;

create or replace function public.hub_select_project(p_token text, p_title text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare v bigint := public.hub_led_team(public.hub_student(p_token));
begin
  if (select status from public.hub_teams where id = v) <> 'Forming' then
    raise exception 'Your team already has a project. Release it first.'; end if;
  if not exists (select 1 from public.hub_projects where title = p_title) then raise exception 'Unknown project.'; end if;
  begin
    update public.hub_teams set project_title = p_title, status = 'Selected', updated_at = now() where id = v;
  exception when unique_violation then
    raise exception 'Sorry, another team has just taken this project.';
  end;
end $$;

create or replace function public.hub_release_project(p_token text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare v bigint := public.hub_led_team(public.hub_student(p_token));
begin
  if (select status from public.hub_teams where id = v) not in ('Selected','Changes Required') then
    raise exception 'The project can only be released before approval.'; end if;
  update public.hub_teams set project_title = null, innovation = null, status = 'Forming', updated_at = now() where id = v;
end $$;

create or replace function public.hub_submit_proposal(p_token text, p_innovation text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare v bigint := public.hub_led_team(public.hub_student(p_token));
begin
  if (select status from public.hub_teams where id = v) not in ('Selected','Changes Required') then
    raise exception 'Select a project first (or the proposal is already submitted).'; end if;
  if (select count(*) from public.hub_members where team_id = v and status = 'accepted') < 2 then
    raise exception 'At least 2 members must accept before submitting.'; end if;
  if length(trim(coalesce(p_innovation,''))) < 30 then
    raise exception 'Describe the proposed innovation in at least 30 characters.'; end if;
  delete from public.hub_members where team_id = v and status = 'invited';
  update public.hub_teams set innovation = trim(p_innovation), status = 'Pending Approval', updated_at = now() where id = v;
end $$;

create or replace function public.hub_set_milestone(p_token text, p_index int, p_done boolean) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare v bigint := public.hub_team_of(public.hub_student(p_token)); m boolean[]; pct int;
begin
  if v is null then raise exception 'You are not in a team.'; end if;
  if p_index not between 1 and 7 then raise exception 'Invalid milestone.'; end if;
  if (select status from public.hub_teams where id = v) not in ('Approved','Ready for Final Review') then
    raise exception 'Milestones open after faculty approval.'; end if;
  select milestones into m from public.hub_teams where id = v;
  m[p_index] := p_done;
  pct := round(100.0 * (select count(*) from unnest(m) x where x) / 7);
  update public.hub_teams set milestones = m, progress = pct,
    status = case when pct = 100 then 'Ready for Final Review' else 'Approved' end, updated_at = now()
  where id = v;
end $$;

create or replace function public.hub_add_update(p_token text, p_body text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare me uuid := public.hub_student(p_token); v bigint := public.hub_team_of(me);
begin
  if v is null then raise exception 'You are not in a team.'; end if;
  if (select status from public.hub_teams where id = v) not in ('Approved','Ready for Final Review') then
    raise exception 'Work updates open after faculty approval.'; end if;
  insert into public.hub_updates(team_id, author_id, body) values (v, me, trim(p_body));
end $$;

-- ---------- 7. Faculty functions (p_token = Explorer Teacher Login token) ----------
create or replace function public.hub_faculty_teams(p_token text) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
begin
  perform public.hub_require_teacher(p_token);
  return coalesce((select jsonb_agg(public.hub_team_json(id) order by updated_at desc) from public.hub_teams), '[]'::jsonb);
end $$;

-- p_action: approve | changes | reject | unlock | complete
create or replace function public.hub_faculty_action(p_token text, p_team bigint, p_action text, p_remark text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare t public.hub_teams; r record;
begin
  perform public.hub_require_teacher(p_token);
  select * into t from public.hub_teams where id = p_team;
  if t.id is null then raise exception 'Team not found.'; end if;

  if p_action = 'approve' then
    if t.status <> 'Pending Approval' then raise exception 'Only pending proposals can be approved.'; end if;
    update public.hub_teams set status = 'Approved', faculty_remark = p_remark, updated_at = now() where id = p_team;
  elsif p_action = 'changes' then                    -- team keeps the project, edits and resubmits
    if t.status <> 'Pending Approval' then raise exception 'Only pending proposals can be returned.'; end if;
    update public.hub_teams set status = 'Changes Required', faculty_remark = p_remark, updated_at = now() where id = p_team;
  elsif p_action in ('reject','unlock') then          -- project released, team stays together
    if t.status = 'Completed' then raise exception 'Completed projects cannot be changed.'; end if;
    update public.hub_teams set status = 'Forming', project_title = null, innovation = null,
      milestones = array[false,false,false,false,false,false,false], progress = 0,
      faculty_remark = p_remark, updated_at = now() where id = p_team;
  elsif p_action = 'complete' then
    if t.status <> 'Ready for Final Review' then raise exception 'The team must complete all milestones first.'; end if;
    update public.hub_teams set status = 'Completed', completed_on = current_date,
      faculty_remark = p_remark, updated_at = now() where id = p_team;
    for r in select s.id, s.student_name, s.student_id from public.hub_members m
             join public."STUDENTS" s on s.id = m.student_id
             where m.team_id = p_team and m.status = 'accepted' loop
      insert into public.hub_certificates(cert_id, team_id, student_id, student_name, usn, team_name, project_title, project_type)
      values ('DVIH-' || to_char(now(),'YY') || '-' || upper(encode(extensions.gen_random_bytes(4),'hex')),
              p_team, r.id, r.student_name, r.student_id, t.name, t.project_title,
              (select type from public.hub_projects where title = t.project_title));
    end loop;
  else
    raise exception 'Unknown action.';
  end if;
end $$;

-- ---------- 8. Permissions (only hub_ functions are touched) ----------
revoke all on function public.hub_norm_sem(text), public.hub_norm_sec(text), public.hub_student(text),
  public.hub_require_teacher(text), public.hub_team_of(uuid), public.hub_led_team(uuid),
  public.hub_team_json(bigint), public.hub_editable(bigint), public.hub_taken_projects(),
  public.hub_verify_certificate(text), public.hub_my_state(text), public.hub_create_team(text,text),
  public.hub_invite(text,text), public.hub_respond_invite(text,bigint,boolean),
  public.hub_remove_member(text,uuid), public.hub_leave_team(text), public.hub_disband_team(text),
  public.hub_select_project(text,text), public.hub_release_project(text),
  public.hub_submit_proposal(text,text), public.hub_set_milestone(text,int,boolean),
  public.hub_add_update(text,text), public.hub_faculty_teams(text),
  public.hub_faculty_action(text,bigint,text,text)
  from public, anon, authenticated;

grant execute on function public.hub_taken_projects(), public.hub_verify_certificate(text),
  public.hub_my_state(text), public.hub_create_team(text,text), public.hub_invite(text,text),
  public.hub_respond_invite(text,bigint,boolean), public.hub_remove_member(text,uuid),
  public.hub_leave_team(text), public.hub_disband_team(text), public.hub_select_project(text,text),
  public.hub_release_project(text), public.hub_submit_proposal(text,text),
  public.hub_set_milestone(text,int,boolean), public.hub_add_update(text,text),
  public.hub_faculty_teams(text), public.hub_faculty_action(text,bigint,text,text)
  to anon, authenticated;

notify pgrst, 'reload schema';
