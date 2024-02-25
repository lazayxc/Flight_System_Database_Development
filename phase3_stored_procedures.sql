-- CS4400: Introduction to Database Systems: Tuesday, September 12, 2023
-- Simple Airline Management System Course Project Mechanics [TEMPLATE] (v0)
-- Views, Functions & Stored Procedures

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'flight_tracking';
use flight_tracking;
-- -----------------------------------------------------------------------------
-- stored procedures and views
-- -----------------------------------------------------------------------------
/* Standard Procedure: If one or more of the necessary conditions for a procedure to
be executed is false, then simply have the procedure halt execution without changing
the database state. Do NOT display any error messages, etc. */

-- [_] supporting functions, views and stored procedures
-- -----------------------------------------------------------------------------
/* Helpful library capabilities to simplify the implementation of the required
views and procedures. */
-- -----------------------------------------------------------------------------
drop function if exists leg_time;
delimiter //
create function leg_time (ip_distance integer, ip_speed integer)
	returns time reads sql data
begin
	declare total_time decimal(10,2);
    declare hours, minutes integer default 0;
    set total_time = ip_distance / ip_speed;
    set hours = truncate(total_time, 0);
    set minutes = truncate((total_time - hours) * 60, 0);
    return maketime(hours, minutes, 0);
end //
delimiter ;

-- my function
drop function if exists airplane_type_of_flight;
delimiter //
create function airplane_type_of_flight(ip_flightID varchar(50))
	returns varchar(100) deterministic
begin
	declare result_airplane_type varchar(100);

    select plane_type
    into result_airplane_type
	from airplane
	join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail
	where flight.flightID = ip_flightID;

    return result_airplane_type;
end //
delimiter ;

drop function if exists airplane_locationID_of_flight;
delimiter //
create function airplane_locationID_of_flight(ip_flightID varchar(50))
	returns varchar(50) deterministic
begin
	declare result_locationID varchar(50);

    select locationID
    into result_locationID
	from airplane
	join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail
	where flight.flightID = ip_flightID;

    return result_locationID;
end //
delimiter ;

drop function if exists landing_airportID_of_flight;
delimiter //
create function landing_airportID_of_flight(ip_flightID varchar(50))
	returns varchar(50) deterministic
begin
	declare result_airportID varchar(50);

	select arrival
    into result_airportID
	from leg
	where legID = 
		(select route_path.legID
		from route_path
		join flight on flight.routeID = route_path.routeID
		where flight.flightID = ip_flightID and route_path.sequence = flight.progress);

    return result_airportID;
end //
delimiter ;

drop function if exists taking_off_airportID_of_flight;
delimiter //
create function taking_off_airportID_of_flight(ip_flightID varchar(50))
	returns varchar(50) deterministic
begin
	declare result_airportID varchar(50);

	select departure
    into result_airportID
	from leg
	where legID = 
		(select route_path.legID
		from route_path
		join flight on flight.routeID = route_path.routeID
		where flight.flightID = ip_flightID and route_path.sequence = flight.progress);

    return result_airportID;
end //
delimiter ;

drop function if exists airportID_of_flight;
delimiter //
create function airportID_of_flight(ip_flightID varchar(50))
	returns varchar(50) deterministic
begin
	declare result_airportID varchar(50);

	-- most start airport
	if (select progress from flight where flightID = ip_flightID) = 0 then
		select departure
		into result_airportID
		from leg
		where legID = 
			(select route_path.legID
			from route_path
			join flight on flight.routeID = route_path.routeID
			where flight.flightID = ip_flightID and route_path.sequence = 1);
	elseif (select airplane_status from flight where flightID = ip_flightID) = 'on_ground' then
		select landing_airportID_of_flight(ip_flightID)
		into result_airportID;
	else
		set result_airportID = null;
	end if;

    return result_airportID;
end //
delimiter ;

drop function if exists get_departure_by_routeID_and_seq_on_ground;
delimiter //
create function get_departure_by_routeID_and_seq_on_ground (ip_routeID varchar(50), ip_seq int)
    returns char(3) reads sql data
begin
    declare dep char(3);
    
    -- `progress=0` and `progress=1` actually refer to the same leg
    if ip_seq = 0 then
        select departure into dep from leg where legID = (
            select legID from route_path
            where routeID = ip_routeID and sequence = 1
        );
    else
        select arrival into dep from leg where legID = (
            select legID from route_path
            where routeID = ip_routeID and sequence = ip_seq
        );
    end if;

    return dep;
end //
delimiter ;

drop function if exists get_departure_by_routeID_and_seq_in_air;
delimiter //
create function get_departure_by_routeID_and_seq_in_air (ip_routeID varchar(50), ip_seq int)
    returns char(3) reads sql data
begin
    declare dep char(3);
    
    select departure into dep from leg where legID = (
        select legID from route_path
        where routeID = ip_routeID and sequence = ip_seq
    );
    return dep;
end //
delimiter ;

drop function if exists get_arrival_by_routeID_and_seq_in_air;
delimiter //
create function get_arrival_by_routeID_and_seq_in_air (ip_routeID varchar(50), ip_seq int)
    returns char(3) reads sql data
begin
    declare arri char(3);
    
    select arrival into arri from leg where legID = (
        select legID from route_path
        where routeID = ip_routeID and sequence = ip_seq
    );
    return arri;
end //
delimiter ;

-- [1] add_airplane()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airplane.  A new airplane must be sponsored
by an existing airline, and must have a unique tail number for that airline.
username.  An airplane must also have a non-zero seat capacity and speed. An airplane
might also have other factors depending on it's type, like skids or some number
of engines.  Finally, an airplane must have a new and database-wide unique location
since it will be used to carry passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airplane;
delimiter //
create procedure add_airplane (in ip_airlineID varchar(50), in ip_tail_num varchar(50),
	in ip_seat_capacity integer, in ip_speed integer, in ip_locationID varchar(50),
    in ip_plane_type varchar(100), in ip_skids boolean, in ip_propellers integer,
    in ip_jet_engines integer)
sp_main: begin
	if ip_airlineID not in (select airlineID from airline)
		then leave sp_main; end if;
	if (select exists (select airlineID, tail_num from airplane where airlineID = ip_airlineID and tail_num = ip_tail_num)) = 1
		then leave sp_main; end if;
	if ip_seat_capacity <= 0
		then leave sp_main; end if;
	if ip_speed <= 0
		then leave sp_main; end if;
	if ip_locationID is null
		then leave sp_main; end if;
	if ip_locationID in (select locationID from airplane)
		then leave sp_main;
	else
		insert into location values (ip_locationID); end if;
        
    insert into airplane values (ip_airlineID, ip_tail_num, ip_seat_capacity, ip_speed, 
    ip_locationID, ip_plane_type, ip_skids, ip_propellers, ip_jet_engines);
end //
delimiter ;



-- [2] add_airport()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new airport.  A new airport must have a unique
identifier along with a new and database-wide unique location if it will be used
to support airplane takeoffs and landings.  An airport may have a longer, more
descriptive name.  An airport must also have a city, state, and country designation. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_airport;
delimiter //
create procedure add_airport (in ip_airportID char(3), in ip_airport_name varchar(200),
    in ip_city varchar(100), in ip_state varchar(100), in ip_country char(3), in ip_locationID varchar(50))
sp_main: begin
	if ip_airportID in (select airportID from airport)
		then leave sp_main; end if;
	if ip_locationID in (select locationID from airport)
		then leave sp_main; end if;
    if ip_city is null
		then leave sp_main; end if;    
    if ip_state is null
		then leave sp_main; end if; 
    if ip_country is null
		then leave sp_main; end if; 
	
    insert into location values (ip_locationID); 
    insert into airport values (ip_airportID, ip_airport_name, ip_city, ip_state, ip_country, ip_locationID);
end //
delimiter ;



-- [3] add_person()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new person.  A new person must reference a unique
identifier along with a database-wide unique location used to determine where the
person is currently located: either at an airport, or on an airplane, at any given
time.  A person must have a first name, and might also have a last name.

A person can hold a pilot role or a passenger role (exclusively).  As a pilot,
a person must have a tax identifier to receive pay, and an experience level.  As a
passenger, a person will have some amount of frequent flyer miles, along with a
certain amount of funds needed to purchase tickets for flights. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_person;
delimiter //
create procedure add_person (in ip_personID varchar(50), in ip_first_name varchar(100),
    in ip_last_name varchar(100), in ip_locationID varchar(50), in ip_taxID varchar(50),
    in ip_experience integer, in ip_miles integer, in ip_funds integer)
sp_main: begin
	if ip_personID in (select personID from person)
		then leave sp_main; end if;
    if ip_locationID not in ((select locationID from airport where locationID is not null) 
							union (select locationID from airplane where locationID is not null))   # not in cannot contain null
		then leave sp_main; end if;
    if ip_first_name is null
		then leave sp_main; end if;
        
    if (ip_taxID is not null) and (ip_experience is not null) and (ip_miles is null) and (ip_funds is null)
		then insert into person values (ip_personID, ip_first_name, ip_last_name, ip_locationID);
             insert into pilot values (ip_personID, ip_taxID, ip_experience, null); 
	elseif (ip_taxID is null) and (ip_experience is null) and (ip_miles is not null) and (ip_funds is not null)		
		then insert into person values (ip_personID, ip_first_name, ip_last_name, ip_locationID);
             insert into passenger values (ip_personID, ip_miles, ip_funds);              
	else
		leave sp_main; end if;
        
end //
delimiter ;

-- [4] grant_or_revoke_pilot_license()
-- -----------------------------------------------------------------------------
/* This stored procedure inverts the status of a pilot license.  If the license
doesn't exist, it must be created; and, if it already exists, then it must be removed. */
-- -----------------------------------------------------------------------------
drop procedure if exists grant_or_revoke_pilot_license;
delimiter //
create procedure grant_or_revoke_pilot_license (in ip_personID varchar(50), in ip_license varchar(100))
sp_main: begin
	if (select exists(select * from pilot_licenses where personID = ip_personID and license = ip_license)) = 1
		then delete from pilot_licenses where (personID = ip_personID and license = ip_license);
	else
		insert into pilot_licenses values (ip_personID, ip_license); end if;
end //
delimiter ;


-- [5] offer_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new flight.  The flight can be defined before
an airplane has been assigned for support, but it must have a valid route.  And
the airplane, if designated, must not be in use by another flight.  The flight
can be started at any valid location along the route except for the final stop,
and it will begin on the ground.  You must also include when the flight will
takeoff along with its cost. */
-- -----------------------------------------------------------------------------


drop procedure if exists offer_flight;
delimiter //
create procedure offer_flight (in ip_flightID varchar(50), in ip_routeID varchar(50),
    in ip_support_airline varchar(50), in ip_support_tail varchar(50), in ip_progress integer, 
    in ip_next_time time, in ip_cost integer)
sp_main: begin


create or replace view route_leg as
SELECT r.routeID, r.legID, r.sequence, l.distance, l.departure, l.arrival
FROM flight_tracking.route_path r
left join leg l on l.legID = r.legID;

create or replace view flight_plane_loc as
select *
from flight f
join airplane a on f.support_airline = a.airlineID and f.support_tail = a.tail_num;

create or replace view passenger_loc as
select personID, locationID
from person 
where personID in (select personid from passenger);

create or replace view flight_leg_sequence as
select f.flightid, r.routeid, r.sequence, r.arrival 
from route_leg r
join flight f on r.routeid = f.routeid
order by f.flightid, r.sequence;

create or replace view flight_final_leg as
select flightid, routeid, max(sequence) as last_leg from flight_leg_sequence group by flightid;

create or replace view flight_final_destination as
select ff.flightid, ff.routeid, ff.last_leg, fls.arrival
from flight_final_leg ff
join flight_leg_sequence fls on ff.flightid = fls.flightid and ff.last_leg = fls.sequence;


	# must have a valid routeid
	if ip_routeID not in (select routeID from route)
		then leave sp_main; end if;
	
    # airplane cannot support other flights
	if (select exists(select support_airline, support_tail from flight 
	where support_airline = ip_support_airline and support_tail = ip_support_tail)) = 1
		then leave sp_main; end if; 
        
	# must have next_time and cost
    if ip_next_time is null or ip_cost is null
		then leave sp_main; end if;
        
	### if progress >= max(sequence of the route, not flight) then leave
    if ip_progress >= (select last_leg from flight_final_destination where routeid = ip_routeID)
		then leave sp_main; end if;
        
	### (ignore these 2 lines) if ip_routeID in (select * from loop_route) # and progress = 1
    	### then leave sp_main; end if;
        
	insert into flight values (ip_flightID, ip_routeID, ip_support_airline, 
		ip_support_tail, ip_progress, 'on_ground', ip_next_time, ip_cost);
    
end //
delimiter ;

-- [6] flight_landing()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight landing at the next airport
along it's route.  The time for the flight should be moved one hour into the future
to allow for the flight to be checked, refueled, restocked, etc. for the next leg
of travel.  Also, the pilots of the flight should receive increased experience, and
the passengers should have their frequent flyer miles updated. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_landing;
delimiter //
create procedure flight_landing (in ip_flightID varchar(50))
sp_main: begin

-- Get the distance and the arrival locationID
declare v_distance integer;
declare v_airport_locID varchar(50);

select leg.distance into v_distance
from flight, route_path, leg
where (flight.routeID = route_path.routeID and
route_path.legID = leg.legID and
flight.flightID = ip_flightID and 
route_path.sequence = flight.progress);

-- Update airplane status
update flight set 
    airplane_status = 'on_ground',
    next_time = ADDTIME(next_time, '01:00:00')
where flightID = ip_flightID;

-- Update pilots' experience
create temporary table if not exists TempPilotIDs as
    select personID
    from pilot
    where commanding_flight = ip_flightID;

update pilot
set experience = experience + 1
where personID in (select personID from TempPilotIDs);

drop temporary table if exists TempPilotIDs;

-- Update customers' miles earned
create temporary table if not exists TempPassengerIDs as
    select person.personID
    from person
    join passenger on person.personID = passenger.personID
    join airplane on person.locationID = airplane.locationID
    join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail
    where flight.flightID = ip_flightID;

update passenger
set miles = miles + v_distance
where personID in (select personID from TempPassengerIDs);

drop temporary table if exists TempPassengerIDs;

end //
delimiter ;

-- [7] flight_takeoff()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a flight taking off from its current
airport towards the next airport along it's route.  The time for the next leg of
the flight must be calculated based on the distance and the speed of the airplane.
And we must also ensure that propeller driven planes have at least one pilot
assigned, while jets must have a minimum of two pilots. If the flight cannot take
off because of a pilot shortage, then the flight must be delayed for 30 minutes. */
-- -----------------------------------------------------------------------------
drop procedure if exists flight_takeoff;
delimiter //
create procedure flight_takeoff (in ip_flightID varchar(50))
sp_main: begin

declare v_plane_type varchar(100);
declare v_speed integer;
declare v_distance integer;
declare v_pilot_count integer;
declare v_required_pilots integer;
declare v_current_status varchar(100);
declare v_max_sequence integer;
declare v_current_progress integer;

-- Get the plane type
select airplane.plane_type, airplane.speed into v_plane_type, v_speed
from flight
join airplane on flight.support_airline = airplane.airlineID and flight.support_tail = airplane.tail_num
where flight.flightID = ip_flightID;

-- Required number of pilots
set v_required_pilots = case
    when v_plane_type = 'prop' then 1
    when v_plane_type = 'jet' then 2
end;

-- Get the number of assigned pilots
select count(*) into v_pilot_count
from pilot
where commanding_flight = ip_flightID;

-- Get the airplane status
select airplane_status into v_current_status
from flight
where flightID = ip_flightID;

-- Get the current progress
select progress into v_current_progress
from flight
where flightID = ip_flightID;

-- Get the max sequence ID
select max(sequence) into v_max_sequence
from route_path
where routeID = (select routeID from flight where flightID = ip_flightID);

-- Check
if v_current_status = 'on_ground' and v_current_progress < v_max_sequence then
	if v_pilot_count < v_required_pilots then
		-- Delayed for 30 minutes
		update flight 
		set next_time = ADDTIME(next_time, '00:30:00')
		where flightID = ip_flightID;
	else
		-- Get the distance
		select leg.distance into v_distance
		from flight, route_path, leg
		where (flight.routeID = route_path.routeID and
		route_path.legID = leg.legID and
		flight.flightID = ip_flightID and 
		route_path.sequence = (flight.progress + 1));

		-- Update next time
		update flight 
		set 
			progress = progress + 1,
			next_time = ADDTIME(next_time, SEC_TO_TIME(v_distance * 3600 / v_speed)),
			airplane_status = 'in_flight'
		where flightID = ip_flightID;
	end if;
end if;

end //
delimiter ;

-- [8] passengers_board()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting on a flight at
its current airport.  The passengers must be at the same airport as the flight,
and the flight must be heading towards that passenger's desired destination.
Also, each passenger must have enough funds to cover the flight.  Finally, there
must be enough seats to accommodate all boarding passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_board;
delimiter //
create procedure passengers_board (in ip_flightID varchar(50))
sp_main: begin

declare v_departure_airport char(3);
declare v_next_airport char(3);
declare v_flight_cost integer;
declare v_seat_capacity integer;
declare v_available_seats integer;
declare v_airplane_locationID varchar(50);
declare v_boarding_passenger_count integer;

-- Get the locationID
select locationID into v_airplane_locationID
from airplane
join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail
where flight.flightID = ip_flightID;

-- Get the departure and arrival
select departure, arrival into v_departure_airport, v_next_airport
from leg
join route_path on leg.legID = route_path.legID
join flight on route_path.routeID = flight.routeID
where flight.flightID = ip_flightID and route_path.sequence = flight.progress + 1;

-- Get the cost and seat capacity
select cost, seat_capacity into v_flight_cost, v_seat_capacity
from flight
join airplane on flight.support_airline = airplane.airlineID and flight.support_tail = airplane.tail_num
where flight.flightID = ip_flightID;

-- Calculate available seats
select v_seat_capacity - count(*) into v_available_seats
from person
join passenger on person.personID = passenger.personID
join airplane on person.locationID = airplane.locationID
join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail
where flight.flightID = ip_flightID;

-- calculate eligible passengers to board
-- Only consider when the passenger_vacations.sequence = 1 the desired destination
select count(*) into v_boarding_passenger_count
from person
join passenger on person.personID = passenger.personID
join passenger_vacations on person.personID = passenger_vacations.personID
join (
    select route_path.routeID, route_path.sequence, leg.arrival
    from route_path
    join leg on route_path.legID = leg.legID
    where routeID = (select routeID from flight where flightID = ip_flightID) and sequence >= (select progress from flight where flightID = ip_flightID)
) as future_destinations on passenger_vacations.airportID = future_destinations.arrival
where person.locationID = (select locationID from airport where airportID = v_departure_airport) 
    and funds >= v_flight_cost
    and passenger_vacations.sequence = 1;

-- check if there are enough seats for all eligible passengers
if v_boarding_passenger_count <= v_available_seats then
    -- update passengers' information
    update passenger
    join person on passenger.personID = person.personID
    join passenger_vacations on passenger.personID = passenger_vacations.personID
    join (
        select route_path.routeID, route_path.sequence, leg.arrival
        from route_path
        join leg on route_path.legID = leg.legID
        where routeID = (select routeID from flight where flightID = ip_flightID) and sequence >= (select progress from flight where flightID = ip_flightID)
    ) as future_destinations on passenger_vacations.airportID = future_destinations.arrival
    set 
        person.locationID = v_airplane_locationID,
        funds = funds - v_flight_cost
    where 
        person.locationID = (select locationID from airport where airportID = v_departure_airport) 
        and funds >= v_flight_cost
        and passenger_vacations.sequence = 1;
end if;
    
end //
delimiter ;

-- [9] passengers_disembark()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for passengers getting off of a flight
at its current airport.  The passengers must be on that flight, and the flight must
be located at the destination airport as referenced by the ticket. */
-- -----------------------------------------------------------------------------
drop procedure if exists passengers_disembark;
delimiter //
create procedure passengers_disembark (in ip_flightID varchar(50))
sp_main: begin
	
    declare disemark_passenger_id varchar(50);
	
	-- the flight must be located at the dest
	if (select airplane_status from flight where flightID = ip_flightID) != 'on_ground'
	then leave sp_main; end if;
    
    -- progress = 0 exit
	if (select progress from flight where flightID = ip_flightID) = 0
	then leave sp_main; end if;
    
    create temporary table if not exists disemark_passenger_ID as
    select person.personID into disemark_passenger_id
		from person join passenger_vacations on person.personID = passenger_vacations.personID
		where -- person is passenger
			person.personID in (select personID from passenger)
		and  -- person is on the plane of the flight
			person.locationID = airplane_locationID_of_flight(ip_flightID)
		and -- landing_airport is their destination
			passenger_vacations.airportID = landing_airportID_of_flight(ip_flightID)
		and -- vacation sequence = 1
			passenger_vacations.sequence = 1;
	
	update person
	set locationID = -- change location from the airplane to the airport 
		(select locationID from airport where airportID = landing_airportID_of_flight(ip_flightID))
	where personID in (select personID from disemark_passenger_ID);
    
    delete from passenger_vacations
    where 
		personID in (select personID from disemark_passenger_ID)
	and
		sequence = 1;
    
    update passenger_vacations
    set sequence = sequence - 1
    where personID in (select personID from disemark_passenger_ID);
    
    drop temporary table if exists disemark_passenger_ID;
    
end //
delimiter ;

-- [10] assign_pilot()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a pilot as part of the flight crew for a given
flight.  The pilot being assigned must have a license for that type of airplane,
and must be at the same location as the flight.  Also, a pilot can only support
one flight (i.e. one airplane) at a time.  The pilot must be assigned to the flight
and have their location updated for the appropriate airplane. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_pilot;
delimiter //
create procedure assign_pilot (in ip_flightID varchar(50), ip_personID varchar(50))
sp_main: begin

	if ip_personID not in 
		(select personID
			from person
			where personID in 
				(select pilot.personID -- person is pilot
				from pilot right join pilot_licenses on pilot.personID = pilot_licenses.personID
				where -- the pilost has the license for the type of airplane of the flight
					pilot_licenses.license like CONCAT('%', airplane_type_of_flight(ip_flightID), '%')
				and -- the pilost has no airplane to command now
					pilot.commanding_flight is null)
			and -- the pilot is on the same airport of the flight to command
				locationID = (select locationID from airport where airportID = airportID_of_flight(ip_flightID)))
	then leave sp_main;
	end if;

	update pilot
	set commanding_flight =  ip_flightID
	where personID = ip_personID;
					
	update person
	set locationID =  airplane_locationID_of_flight(ip_flightID)
	where personID = ip_personID;
    
end //
delimiter ;

-- [11] recycle_crew()
-- -----------------------------------------------------------------------------
/* This stored procedure releases the assignments for a given flight crew.  The
flight must have ended, and all passengers must have disembarked. */
-- -----------------------------------------------------------------------------

drop procedure if exists recycle_crew;
delimiter //
create procedure recycle_crew (in ip_flightID varchar(50))
sp_main: begin

create or replace view route_leg as
SELECT r.routeID, r.legID, r.sequence, l.distance, l.departure, l.arrival
FROM flight_tracking.route_path r
left join leg l on l.legID = r.legID;


create or replace view flight_plane_loc as
select *
from flight f
join airplane a on f.support_airline = a.airlineID and f.support_tail = a.tail_num;

create or replace view passenger_loc as
select personID, locationID
from person 
where personID in (select personid from passenger);

create or replace view flight_leg_sequence as
select f.flightid, r.sequence, r.arrival 
from route_leg r
join flight f on r.routeid = f.routeid
order by f.flightid, r.sequence;

create or replace view flight_final_leg as
select flightid, max(sequence) as last_leg from flight_leg_sequence group by flightid;

create or replace view flight_final_destination as
select ff.flightid, ff.last_leg, fls.arrival
from flight_final_leg ff
join flight_leg_sequence fls on ff.flightid = fls.flightid and ff.last_leg = fls.sequence;



	#######　ignore this line: if current_time() < final time = starting time + airplane speed * total route distance, #if lack of pilot，延误30 min
    
    # condition 0: flight id must be valid (in flight table)
    
    # Condition 1: the flight is on the ground
		if ip_flightID in (select flightid from flight where airplane_status != 'on_ground')
			then leave sp_main; end if;
            
    # Condition 2: its progress number is the last leg of the flight
		if (select progress from flight where flightid = ip_flightID) != (select last_leg from flight_final_leg where flightid = ip_flightID)
			then leave sp_main; end if;            
            
    # Condition 3: no passenger have the same locationID as the plane for the flight.
        if (select locationID from flight_plane_loc where flightID = ip_flightID) in (select locationID from passenger_loc)
			then leave sp_main; end if;

    # do 1: set person.location to airport location
		update person set locationid = (select locationid from airport where airportid = 
											(select arrival from flight_final_destination where flightid = ip_flightID)) 
							where personid in (select personid from pilot where commanding_flight = ip_flightID);
                                            
    # do 2: set pilot.commanding_flight to null
        update pilot set commanding_flight = null where commanding_flight = ip_flightID;
        
end //
delimiter ;

-- [12] retire_flight()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a flight that has ended from the system.  The
flight must be on the ground, and either be at the start its route, or at the
end of its route.  And the flight must be empty - no pilots or passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists retire_flight;
delimiter //
create procedure retire_flight (in ip_flightID varchar(50))
sp_main: begin

    declare flight_id varchar(50);
    declare route_id varchar(50);
    declare airline varchar(50);
    declare tail varchar(50);
    declare prog int;
    declare status varchar(100);
    
    declare max_progress int;
    declare loc_id varchar(50);
    declare person_cnt int;
    
    declare EXIT handler for not found begin end;
    
    select flightID, routeID, support_airline, support_tail, progress, airplane_status
    into flight_id, route_id, airline, tail, prog, status
    from flight where flightID = ip_flightID;
    
    if status != 'on_ground' then
        leave sp_main;
    end if;
    
    -- find the maximum progress value
    select max(sequence) into max_progress
    from route_path where routeID = route_id;
    
    if prog != 0 and @prog != max_progress then
        leave sp_main;
    end if;
    
    -- find the locationID of the plane
    select locationID into loc_id from airplane
    where airlineID = airline and tail_num = tail;
    
    if loc_id is null then
        delete from flight where flightID = ip_flightID;
        leave sp_main;
    end if;
    
    -- find the number of passengers on the plane
    select count(*) into person_cnt from person where locationID = loc_id;
    
    if person_cnt = 0 then
        delete from flight where flightID = ip_flightID;
    end if;
    
end //
delimiter ;

-- [13] simulation_cycle()
-- -----------------------------------------------------------------------------
/* This stored procedure executes the next step in the simulation cycle.  The flight
with the smallest next time in chronological order must be identified and selected.
If multiple flights have the same time, then flights that are landing should be
preferred over flights that are taking off.  Similarly, flights with the lowest
identifier in alphabetical order should also be preferred.

If an airplane is in flight and waiting to land, then the flight should be allowed
to land, passengers allowed to disembark, and the time advanced by one hour until
the next takeoff to allow for preparations.

If an airplane is on the ground and waiting to takeoff, then the passengers should
be allowed to board, and the time should be advanced to represent when the airplane
will land at its next location based on the leg distance and airplane speed.

If an airplane is on the ground and has reached the end of its route, then the
flight crew should be recycled to allow rest, and the flight itself should be
retired from the system. */
-- -----------------------------------------------------------------------------
drop procedure if exists simulation_cycle;
delimiter //
create procedure simulation_cycle ()
sp_main: begin

	declare next_flight varchar(50);
    declare flight_status varchar(100);
    declare flight_route varchar(50);
    declare flight_progress integer;
    declare route_max_sequence integer;
	
	-- find next flight
	select flightID into next_flight
	from flight
	-- smallest next time, landing > takingoff(in_flight > on_ground), alphabetical
	order by next_time asc, airplane_status desc, flightID asc limit 1;

	-- find status on ground of in flight
	select airplane_status into flight_status
	from flight
	where flightID = next_flight;
    
    -- run simulation
    if flight_status = 'in_flight' then
		call flight_landing(next_flight);
		call passengers_disembark(next_flight);
    elseif flight_status = 'on_ground' then
		-- find the flight route
		select routeID into flight_route
		from flight
		where flightID = next_flight;
		
        -- find the flight progress
		select progress into flight_progress
		from flight
		where flightID = next_flight;

		-- find the max sequence of route
		select max(sequence) into route_max_sequence
		from route_path
		where routeID = flight_route;
            
		-- check if the on ground flight reaches last progress
		if flight_progress != route_max_sequence then 
			call passengers_board(next_flight);
            call flight_takeoff(next_flight);
		else -- retire flight
			call recycle_crew(next_flight);
            call retire_flight(next_flight);
		end if;
	end if;
    
end //
delimiter ;

-- [14] flights_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently airborne are located. */
-- -----------------------------------------------------------------------------
create or replace view flights_in_the_air (departing_from, arriving_at, num_flights,
	flight_list, earliest_arrival, latest_arrival, airplane_list) as
select taking_off_airportID_of_flight(flightID), 
	   landing_airportID_of_flight(flightID), 
       count(*),
       group_concat(flightID), 
       min(next_time), 
       max(next_time), 
       group_concat(airplane_locationID_of_flight(flightID))
from flight 
where airplane_status = 'in_flight'
group by taking_off_airportID_of_flight(flightID), landing_airportID_of_flight(flightID);

-- [15] flights_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where flights that are currently on the ground are located. */
-- -----------------------------------------------------------------------------
create or replace view flights_on_the_ground (departing_from, num_flights,
    flight_list, earliest_arrival, latest_arrival, airplane_list) as
select
    get_departure_by_routeID_and_seq_on_ground(routeID, progress) as departing_from,
    count(*) as num_flights,
    group_concat(flightID) as flight_list,
    min(next_time) as earliest_arrival,
    max(next_time) as latest_arrival,
    group_concat(locationID) as airplane_list
from
    flight
    join airplane on flight.support_airline = airplane.airlineID and flight.support_tail = airplane.tail_num
where
    flight.airplane_status = 'on_ground'
group by
    get_departure_by_routeID_and_seq_on_ground(routeID, progress)
;

-- [16] people_in_the_air()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently airborne are located. */
-- -----------------------------------------------------------------------------
create or replace view people_in_the_air (departing_from, arriving_at, num_airplanes,
    airplane_list, flight_list, earliest_arrival, latest_arrival, num_pilots,
    num_passengers, joint_pilots_passengers, person_list) as
select
    get_departure_by_routeID_and_seq_in_air(flight.routeID, flight.progress) as departing_from,
    get_arrival_by_routeID_and_seq_in_air(flight.routeID, flight.progress) as arriving_at,
    count(distinct airplane.airlineID, airplane.tail_num) as num_airplanes,
    group_concat(distinct(airplane.locationID)) as airplane_list,
    group_concat(distinct(flight.flightID)) as flight_list,
    min(flight.next_time) as earliest_arrival,
    max(flight.next_time) as latest_arrival,
    count(case when taxID is not null then 1 end) as num_pilots,
    count(case when taxID is null then 1 end) as num_passengers,
    count(*) as joint_pilots_passengers,
    group_concat(person.personID) as person_list
from
    person
    left join passenger on person.personID = passenger.personID
    left join pilot on person.personID = pilot.personID
    join airplane on person.locationID = airplane.locationID
    join flight on airplane.airlineID = flight.support_airline and airplane.tail_num = flight.support_tail
where
    flight.airplane_status = 'in_flight'
group by
    get_departure_by_routeID_and_seq_in_air(flight.routeID, flight.progress),
    get_arrival_by_routeID_and_seq_in_air(flight.routeID, flight.progress)
;

-- [17] people_on_the_ground()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently on the ground are located. */
-- -----------------------------------------------------------------------------
create or replace view people_on_the_ground (departing_from, airport, airport_name,
    city, state, country, num_pilots, num_passengers, joint_pilots_passengers, person_list) as
select
    airportID as departing_from,
    airport.locationID as airport,
    airport_name,
    city,
    state,
    country,
    count(case when taxID is not null then 1 end) as num_pilots,
    count(case when taxID is null then 1 end) as num_passengers,
    count(*) as joint_pilots_passengers,
    group_concat(person.personID) as person_list
from
    person
    left join passenger on person.personID = passenger.personID
    left join pilot on person.personID = pilot.personID
    join airport on person.locationID = airport.locationID
group by
    airportID
;

-- [18] route_summary()
-- -----------------------------------------------------------------------------
/* This view describes how the routes are being utilized by different flights. */
-- -----------------------------------------------------------------------------
create or replace view route_summary (route, num_legs, leg_sequence, route_length,
    num_flights, flight_list, airport_sequence) as
select
    route,
    num_legs,
    leg_sequence,
    route_length,
    count(case when flight.flightID is not null then 1 end) as num_flights,
    group_concat(flight.flightID) as flight_list,
    airport_sequence
from
    (
        select
            route.routeID as route,
            count(route_path.sequence)as num_legs,
            group_concat(route_path.legID order by route_path.sequence) as leg_sequence,
            sum(leg.distance) as route_length,
            group_concat(concat(leg.departure, '->', leg.arrival) order by route_path.sequence) as airport_sequence
        from
            route
            left join route_path on route.routeID = route_path.routeID
            join leg on route_path.legID = leg.legID
        group by
            route.routeID
    ) as route_info
    left join flight on route_info.route = flight.routeID
group by
    route_info.route
;

-- [19] alternative_airports()
-- -----------------------------------------------------------------------------
/* This view displays airports that share the same city and state. */
-- -----------------------------------------------------------------------------
create or replace view alternative_airports (city, state, country, num_airports,
    airport_code_list, airport_name_list) as
select
    city,
    state,
    country,
    count(*) as num_airports,
    group_concat(airportID) as airport_code_list,
    group_concat(airport_name) as airport_name_list
from
    airport
group by
    city, state, country
having
    count(*) > 1
;
