hierarchy -check -top rv64_l2_fsm

select -module {*rv64_l2_probe_engine*}
setattr -mod -set keep_hierarchy 1
select -clear

select -module {*rv64_l2_grant_update_engine*}
setattr -mod -set keep_hierarchy 1
select -clear

select -module {*rv64_l2_probe_planner*}
setattr -mod -set keep_hierarchy 1
select -clear

select -module {*rv64_l2_dir_lookup*}
setattr -mod -set keep_hierarchy 1
select -clear

select -module {*rv64_l2_plru*}
setattr -mod -set keep_hierarchy 1
select -clear
