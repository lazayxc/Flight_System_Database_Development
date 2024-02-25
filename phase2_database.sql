-- CS4400: Introduction to Database Systems: Monday, September 11, 2023
-- Simple Airline Management System Course Project Database TEMPLATE (v0)

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'flight_tracking';
drop database if exists flight_tracking;
create database if not exists flight_tracking;
use flight_tracking;

-- Please enter your team number and names here
-- Team 52: Yang Yang, Huizhou Luo, Xiaochen Yan, Shuo Lin 

-- Define the database structures
/* You must enter your tables definitions, along with your primary, unique and foreign key
declarations, and data insertion statements here.  You may sequence them in any order that
works for you.  When executed, your statements must create a functional database that contains
all of the data, and supports as many of the constraints as reasonably possible. */

-- According to the written requirements, first names will be required, and some celebrities might travel using only their first name (e.g., Madonna, Sade, Beyonce); thus, last names are optional.
-- According to the written requirements, the system must be able to manage first and last names that have one hundred (100) or fewer characters.
-- According to the written requirements, attributes that are used to identify entities in your system will normally consist of fifty (50) or fewer alphanumeric characters
-- According to the written requirements, our default size for storing "general purpose" descriptive attributes will be one hundred (100) or fewer characters unless otherwise noted.

-- location table
drop table if exists location;
create table location (
    locID varchar(50),
    primary key (locID)
) engine=innodb;

-- route table
drop table if exists route;
create table route (
    routeID varchar(50) not null,
    primary key (routeID)
) engine=innodb;

-- flight table
drop table if exists flight;
create table flight (
    flightID varchar(50) not null,
    cost decimal(10,2) default null,
    follow varchar(50) not null,
    primary key (flightID),
    constraint fk1 foreign key (follow) references route (routeID)
) engine=innodb;

-- airport table
drop table if exists airport;
create table airport (
    airportID char(3),
    name varchar(100) not null,
    city varchar(100) not null,
    state varchar(100) not null,
    country char(3) not null,
    locationID varchar(50) default null,
    primary key (airportID),
    constraint fk2 foreign key (locationID) references location(locID)
) engine=innodb;

-- leg table
drop table if exists leg;
create table leg (
    legID varchar(50) not null,
    distance decimal(10,2) default null,
    departs char(3) not null,
    arrives char(3) not null,
    primary key (legID),
    constraint fk3 foreign key (departs) references airport (airportID),
    constraint fk4 foreign key (arrives) references airport (airportID)
) engine=innodb;

-- contain table
drop table if exists contain;
create table contain (
    routeID varchar(50) not null,
    legID varchar(50) not null,
    sequence integer not null,
    primary key (routeID, legID, sequence),
    constraint fk5 foreign key (routeID) references route (routeID),
    constraint fk6 foreign key (legID) references leg (legID)
) engine=innodb;

-- airline table
drop table if exists airline;
create table airline (
    airlineID varchar(50) not null,
    revenue decimal(10, 2) not null, -- cannot be null because it needs to be involved in the calculation of ticket sales.
    primary key (airlineID)
) engine=innodb;

-- airplane table
drop table if exists airplane;
create table airplane (
    airlineID varchar(50) not null,
    tail_num varchar(50) not null,  
    speed decimal(8, 2) not null,    -- airplane speed is normally less than 8 figures 
    seat_cap decimal(4, 0) not null, -- seat capacity is normally less than 4 figures
    locationID varchar(50) default null,
    primary key (airlineID, tail_num),
    constraint fk7 foreign key (airlineID) references airline(airlineID),
    constraint fk8 foreign key (locationID) references location(locID)
) engine=innodb;

-- prop table
drop table if exists prop;
create table prop (
    airlineID varchar(50) not null,
    tail_num varchar(50) not null,
    props decimal(2, 0) default null, -- the number of engines is normally less than 2 figures
    skids boolean default null,
    primary key (airlineID, tail_num),
    constraint fk9 foreign key (airlineID, tail_num) references airplane(airlineID, tail_num)
) engine=innodb;

-- jet table
drop table if exists jet;
create table jet (
    airlineID varchar(50) not null,
    tail_num varchar(50) not null,
    engines decimal(2, 0) default null, -- the number of engines is normally less than 2 figures
    primary key (airlineID, tail_num),
    constraint fk10 foreign key (airlineID, tail_num) references airplane(airlineID, tail_num)
) engine=innodb;

-- supports table
drop table if exists supports;
create table supports (
    airlineID varchar(50),
    plane_tail_num varchar(50),
    flightID varchar(50) not null,
    progress integer not null,
    status enum('on_ground', 'in_flight') not null,
    next_time time not null,
    primary key (airlineID, plane_tail_num),
    unique key (flightID),
    constraint fk11 foreign key (airlineID, plane_tail_num) references airplane(airlineID, tail_num),
    constraint fk12 foreign key (flightID) references flight(flightID)
) engine=innodb;

-- person table
drop table if exists person;
create table person (
	personID varchar(50) not null,
	fname varchar(100) not null,
	lname varchar(100) default null,
	occupies varchar(50) not null,
	primary key (personID),
	constraint fk13 foreign key (occupies) references location (locID)
) engine=innodb;

-- pilot table
-- The taxID attribute is a unique key using a "xxx-xx-xxxx" format.
drop table if exists pilot;
create table pilot (
	personID varchar(50) not null,
	taxID char(11) not null,
	experience integer not null,
	commands varchar(50) default null,
	primary key (personID),
	unique key (taxID),
	constraint fk14 foreign key (personID) references person (personID),
	constraint fk15 foreign key (commands) references flight (flightID)
) engine=innodb;

-- passenger table
-- Decimal with a precision of 10 and a scale of 2 is sufficient for the funds attribute.
-- Decimal with a precision of 10 and a scale of 2 is sufficient for the miles attribute.
drop table if exists passenger;
create table passenger (
	personID varchar(50) not null,
	funds decimal(10, 2) not null,
	miles decimal(10, 2) not null,
    primary key (personID),
	constraint fk16 foreign key (personid) references person (personID)
) engine=innodb;

-- license (multi-valued attribute) table
drop table if exists licenseMV;
create table licenseMV (
    personID varchar(50),
    license varchar(100),
    primary key (personID, license),
    constraint fk17 foreign key (personID) references pilot(personID)
) engine=innodb;

-- vacation (multi-valued attribute) table
drop table if exists vacationMV;
create table vacationMV (
    personID varchar(50),
    destination char(3),
    sequence integer,
    primary key (personID, destination, sequence),
    constraint fk18 foreign key (personID) references passenger(personID)
) engine=innodb;

-- insert location data
insert into location (locID) values
    ('port_1'),
    ('port_2'),
    ('port_3'),
    ('port_10'),
    ('port_17'),
    ('plane_1'),
    ('plane_5'),
    ('plane_8'),
    ('plane_13'),
    ('plane_20'),
    ('port_12'),
    ('port_14'),
    ('port_15'),
    ('port_20'),
    ('port_4'),
    ('port_16'),
    ('port_11'),
    ('port_23'),
    ('port_7'),
    ('port_6'),
    ('port_13'),
    ('port_21'),
    ('port_18'),
    ('port_22'),
    ('plane_6'),
    ('plane_18'),
    ('plane_7');

-- insert route data
insert into route values
('americas_hub_exchange'),
('americas_one'),
('americas_three'),
('americas_two'),
('big_europe_loop'),
('euro_north'),
('euro_south'),
('germany_local'),
('pacific_rim_tour'),
('south_euro_loop'),
('texas_local');


-- insert flight data
insert into flight values
('dl_10',200,'americas_one'),
('un_38',200,'americas_three'),
('ba_61',200,'americas_two'),
('lf_20',300,'euro_north'),
('km_16',400,'euro_south'),
('ba_51',100,'big_europe_loop'),
('ja_35',300,'pacific_rim_tour'),
('ry_34',100,'germany_local');

-- insert airport data
insert into airport (airportID, name, city, state, country, locationID) values
    ('ATL', 'Atlanta Hartsfield_Jackson International', 'Atlanta', 'Georgia', 'USA', 'port_1'),
    ('DXB', 'Dubai International', 'Dubai', 'Al Garhoud', 'UAE', 'port_2'),
    ('HND', 'Tokyo International Haneda', 'Ota City', 'Tokyo', 'JPN', 'port_3'),
    ('LHR', 'London Heathrow', 'London', 'England', 'GBR', 'port_4'),
    ('IST', 'Istanbul International', 'Arnavutkoy', 'Istanbul ', 'TUR', null),
    ('DFW', 'Dallas_Fort Worth International', 'Dallas', 'Texas', 'USA', 'port_6'),
    ('CAN', 'Guangzhou International', 'Guangzhou', 'Guangdong', 'CHN', 'port_7'),
    ('DEN', 'Denver International', 'Denver', 'Colorado', 'USA', null),
    ('LAX', 'Los Angeles International', 'Los Angeles', 'California', 'USA', null),
    ('ORD', 'O_Hare International', 'Chicago', 'Illinois', 'USA', 'port_10'),
    ('AMS', 'Amsterdam Schipol International', 'Amsterdam', 'Haarlemmermeer', 'NLD', 'port_11'),
    ('CDG', 'Paris Charles de Gaulle', 'Roissy_en_France', 'Paris', 'FRA', 'port_12'),
    ('FRA', 'Frankfurt International', 'Frankfurt', 'Frankfurt_Rhine_Main', 'DEU', 'port_13'),
    ('MAD', 'Madrid Adolfo Suarez_Barajas', 'Madrid', 'Barajas', 'ESP', 'port_14'),
    ('BCN', 'Barcelona International', 'Barcelona', 'Catalonia', 'ESP', 'port_15'),
    ('FCO', 'Rome Fiumicino', 'Fiumicino', 'Lazio', 'ITA', 'port_16'),
    ('LGW', 'London Gatwick', 'London', 'England', 'GBR', 'port_17'),
    ('MUC', 'Munich International', 'Munich', 'Bavaria', 'DEU', 'port_18'),
    ('MDW', 'Chicago Midway International', 'Chicago', 'Illinois', 'USA', null),
    ('IAH', 'George Bush Intercontinental', 'Houston', 'Texas', 'USA', 'port_20'),
    ('HOU', 'William P_Hobby International', 'Houston', 'Texas', 'USA', 'port_21'),
    ('NRT', 'Narita International', 'Narita', 'Chiba', 'JPN', 'port_22'),
    ('BER', 'Berlin Brandenburg Willy Brandt International', 'Berlin', 'Schonefeld', 'DEU', 'port_23');

-- insert leg data
insert into leg values
('leg_1', 400, 'AMS', 'BER'),
('leg_2', 3900, 'ATL', 'AMS'),
('leg_3', 3700, 'ATL', 'LHR'),
('leg_4', 600, 'ATL', 'ORD'),
('leg_5', 500, 'BCN', 'CDG'),
('leg_6', 300, 'BCN', 'MAD'),
('leg_7', 4700, 'BER', 'CAN'),
('leg_8', 600, 'BER', 'LGW'),
('leg_9', 300, 'BER', 'MUC'),
('leg_10', 1600, 'CAN', 'HND'),
('leg_11', 500, 'CDG', 'BCN'),
('leg_12', 600, 'CDG', 'FCO'),
('leg_13', 200, 'CDG', 'LHR'),
('leg_14', 400, 'CDG', 'MUC'),
('leg_15', 200, 'DFW', 'IAH'),
('leg_16', 800, 'FCO', 'MAD'),
('leg_17', 300, 'FRA', 'BER'),
('leg_18', 100, 'HND', 'NRT'),
('leg_19', 300, 'HOU', 'DFW'),
('leg_20', 100, 'IAH', 'HOU'),
('leg_21', 600, 'LGW', 'BER'),
('leg_22', 600, 'LHR', 'BER'),
('leg_23', 500, 'LHR', 'MUC'),
('leg_24', 300, 'MAD', 'BCN'),
('leg_25', 600, 'MAD', 'CDG'),
('leg_26', 800, 'MAD', 'FCO'),
('leg_27', 300, 'MUC', 'BER'),
('leg_28', 400, 'MUC', 'CDG'),
('leg_29', 400, 'MUC', 'FCO'),
('leg_30', 200, 'MUC', 'FRA'),
('leg_31', 3700, 'ORD', 'CDG');




-- insert contain data
insert into contain values
('americas_hub_exchange', 'leg_4', 1),
('americas_one', 'leg_2', 1),
('americas_one', 'leg_1', 2),
('americas_three', 'leg_31', 1),
('americas_three', 'leg_14', 2),
('americas_two', 'leg_3', 1),
('americas_two', 'leg_22', 2),
('big_europe_loop', 'leg_23', 1),
('big_europe_loop', 'leg_29', 2),
('big_europe_loop', 'leg_16', 3),
('big_europe_loop', 'leg_25', 4),
('big_europe_loop', 'leg_13', 5),
('euro_north', 'leg_16', 1),
('euro_north', 'leg_24', 2),
('euro_north', 'leg_5', 3),
('euro_north', 'leg_14', 4),
('euro_north', 'leg_27', 5),
('euro_north', 'leg_8', 6),
('euro_south', 'leg_21', 1),
('euro_south', 'leg_9', 2),
('euro_south', 'leg_28', 3),
('euro_south', 'leg_11', 4),
('euro_south', 'leg_6', 5),
('euro_south', 'leg_26', 6),
('germany_local', 'leg_9', 1),
('germany_local', 'leg_30', 2),
('germany_local', 'leg_17', 3),
('pacific_rim_tour', 'leg_7', 1),
('pacific_rim_tour', 'leg_10', 2),
('pacific_rim_tour', 'leg_18', 3),
('south_euro_loop', 'leg_16', 1),
('south_euro_loop', 'leg_24', 2),
('south_euro_loop', 'leg_5', 3),
('south_euro_loop', 'leg_12', 4),
('texas_local', 'leg_15', 1),
('texas_local', 'leg_20', 2),
('texas_local', 'leg_19', 3);


-- insert airline data
insert into airline (airlineID, revenue) values
    ('Delta', 53000),
    ('American', 52000),
    ('United', 48000),
    ('Lufthansa', 35000),
    ('Air_France', 29000),
    ('KLM', 29000),
    ('British Airways', 24000),
    ('China Southern Airlines', 14000),
    ('Ryanair', 10000),
    ('Korean Air Lines', 10000),
    ('Japan Airlines', 9000);

-- insert airplane data
insert into airplane (airlineID, tail_num, speed, seat_cap, locationID) values
    ('Delta', 'n106js', 800, 4, 'plane_1'),
    ('Delta', 'n110jn', 800, 5, null),
    ('Delta', 'n127js', 600, 4, null),
	('American', 'n448cs', 400, 4, null),
    ('American', 'n225sb', 800, 8, null),
    ('American', 'n553qn', 800, 5, null),
    ('United', 'n330ss', 800, 4, null),
    ('United', 'n380sd', 400, 5, 'plane_5'),
    ('Lufthansa', 'n620la', 800, 4, 'plane_8'),
    ('Lufthansa', 'n401fj', 300, 4, null),
    ('Lufthansa', 'n653fk', 600, 6, null),
    ('Air_France', 'n118fm', 400, 4, null),
    ('Air_France', 'n815pw', 400, 3, null),
    ('KLM', 'n161fk', 600, 4, 'plane_13'),
    ('KLM', 'n337as', 400, 5, null),
    ('KLM', 'n256ap', 300, 4, null),
    ('British Airways', 'n616lt', 600, 7, 'plane_6'),
    ('British Airways', 'n517ly', 600, 4, 'plane_7'),
	('China Southern Airlines', 'n454gq', 400, 3, null),
    ('China Southern Airlines', 'n249yk', 400, 4, null),
    ('Ryanair', 'n156sq', 600, 8, null),
    ('Ryanair', 'n451fi', 600, 5, null),
    ('Ryanair', 'n341eb', 400, 4, 'plane_18'),
    ('Ryanair', 'n353kz', 400, 4, null),
    ('Korean Air Lines', 'n180co', 600, 5, null),
    ('Japan Airlines', 'n305fv', 400, 6, 'plane_20'),
    ('Japan Airlines', 'n443wu', 800, 4, null);

-- insert prop data
insert into prop (airlineID, tail_num, props, skids) values
    ('American', 'n448cs', 2, true),
    ('Air_France', 'n118fm', 2, false),
    ('KLM', 'n256ap', 2, false),
    ('China Southern Airlines', 'n249yk', 2, false),
    ('Ryanair', 'n341eb', 2, true),
    ('Ryanair', 'n353kz', 2, true);

-- insert jet data
insert into jet (airlineID, tail_num, engines) values
    ('Delta', 'n106js', 2),
    ('Delta', 'n110jn', 2),
    ('Delta', 'n127js', 4),
    ('American', 'n225sb', 2),
    ('American', 'n553qn', 2),
    ('United', 'n330ss', 2),
    ('United', 'n380sd', 2),
    ('Lufthansa', 'n620la', 4),
    ('Lufthansa', 'n653fk', 2),
    ('Air_France', 'n815pw', 2),
    ('KLM', 'n161fk', 4),
    ('KLM', 'n337as', 2),
    ('British Airways', 'n616lt', 2),
    ('British Airways', 'n517ly', 2),
    ('Ryanair', 'n156sq', 2),
    ('Ryanair', 'n451fi', 4),
    ('Korean Air Lines', 'n180co', 2),
    ('Japan Airlines', 'n305fv', 2),
    ('Japan Airlines', 'n443wu', 4);

-- insert supports data
insert into supports (airlineID, plane_tail_num, flightID, progress, status, next_time) values
    ('Delta', 'n106js', 'dl_10', 1, 'in_flight', '08:00:00'),
    ('United', 'n380sd', 'un_38', 2, 'in_flight', '14:30:00'),
    ('British Airways', 'n616lt', 'ba_61', 0, 'on_ground', '09:30:00'),
    ('Lufthansa', 'n620la', 'lf_20', 3, 'in_flight', '11:00:00'),
    ('KLM', 'n161fk', 'km_16', 6, 'in_flight', '14:00:00'),
    ('British Airways', 'n517ly', 'ba_51', 0, 'on_ground', '11:30:00'),
    ('Japan Airlines', 'n305fv', 'ja_35', 1, 'in_flight', '09:30:00'),
    ('Ryanair', 'n341eb', 'ry_34', 0, 'on_ground', '15:00:00');

-- insert data into person table
insert into person (personID, fname, lname, occupies) values
    ('p1', 'Jeanne', 'Nelson', 'port_1'),
    ('p10', 'Lawrence', 'Morgan', 'port_3'),
    ('p11', 'Sandra', 'Cruz', 'port_3'),
    ('p12', 'Dan', 'Ball', 'port_3'),
    ('p13', 'Bryant', 'Figueroa', 'port_3'),
    ('p14', 'Dana', 'Perry', 'port_3'),
    ('p15', 'Matt', 'Hunt', 'port_10'),
    ('p16', 'Edna', 'Brown', 'port_10'),
    ('p17', 'Ruby', 'Burgess', 'port_10'),
    ('p18', 'Esther', 'Pittman', 'port_10'),
    ('p19', 'Doug', 'Fowler', 'port_17'),
    ('p2', 'Roxanne', 'Byrd', 'port_1'),
    ('p20', 'Thomas', 'Olson', 'port_17'),
    ('p21', 'Mona', 'Harrison', 'plane_1'),
    ('p22', 'Arlene', 'Massey', 'plane_1'),
    ('p23', 'Judith', 'Patrick', 'plane_1'),
    ('p24', 'Reginald', 'Rhodes', 'plane_5'),
    ('p25', 'Vincent', 'Garcia', 'plane_5'),
    ('p26', 'Cheryl', 'Moore', 'plane_5'),
    ('p27', 'Michael', 'Rivera', 'plane_8'),
    ('p28', 'Luther', 'Matthews', 'plane_8'),
    ('p29', 'Moses', 'Parks', 'plane_13'),
    ('p3', 'Tanya', 'Nguyen', 'port_1'),
    ('p30', 'Ora', 'Steele', 'plane_13'),
    ('p31', 'Antonio', 'Flores', 'plane_13'),
    ('p32', 'Glenn', 'Ross', 'plane_13'),
    ('p33', 'Irma', 'Thomas', 'plane_20'),
    ('p34', 'Ann', 'Maldonado', 'plane_20'),
    ('p35', 'Jeffrey', 'Cruz', 'port_12'),
    ('p36', 'Sonya', 'Price', 'port_12'),
    ('p37', 'Tracy', 'Hale', 'port_12'),
    ('p38', 'Albert', 'Simmons', 'port_14'),
    ('p39', 'Karen', 'Terry', 'port_15'),
    ('p4', 'Kendra', 'Jacobs', 'port_1'),
    ('p40', 'Glen', 'Kelley', 'port_20'),
    ('p41', 'Brooke', 'Little', 'port_3'),
    ('p42', 'Daryl', 'Nguyen', 'port_4'),
    ('p43', 'Judy', 'Willis', 'port_14'),
    ('p44', 'Marco', 'Klein', 'port_15'),
    ('p45', 'Angelica', 'Hampton', 'port_16'),
    ('p5', 'Jeff', 'Burton', 'port_1'),
    ('p6', 'Randal', 'Parks', 'port_1'),
    ('p7', 'Sonya', 'Owens', 'port_2'),
    ('p8', 'Bennie', 'Palmer', 'port_2'),
    ('p9', 'Marlene', 'Warner', 'port_3');

-- -- insert data into pilot table
insert into pilot (personID, taxID, experience, commands) values
    ('p1', '330-12-6907', 31, 'dl_10'),
    ('p10', '769-60-1266', 15, 'lf_20'),
    ('p11', '369-22-9505', 22, 'km_16'),
    ('p12', '680-92-5329', 24, 'ry_34'),
    ('p13', '513-40-4168', 24, 'km_16'),
    ('p14', '454-71-7847', 13, 'km_16'),
    ('p15', '153-47-8101', 30, 'ja_35'),
    ('p16', '598-47-5172', 28, 'ja_35'),
    ('p17', '865-71-6800', 36, NULL),
    ('p18', '250-86-2784', 23, NULL),
    ('p19', '386-39-7881', 2, NULL),
    ('p2', '842-88-1257', 9, 'dl_10'),
    ('p20', '522-44-3098', 28, NULL),
    ('p3', '750-24-7616', 11, 'un_38'),
    ('p4', '776-21-8098', 24, 'un_38'),
    ('p5', '933-93-2165', 27, 'ba_61'),
    ('p6', '707-84-4555', 38, 'ba_61'),
    ('p7', '450-25-5617', 13, 'lf_20'),
    ('p8', '701-38-2179', 12, 'ry_34'),
    ('p9', '936-44-6941', 13, 'lf_20');

-- -- insert data into passenger table
insert into passenger (personID, funds, miles) values
	('p21', 700, 771),
	('p22', 200, 374),
	('p23', 400, 414),
	('p24', 500, 292),
	('p25', 300, 390),
	('p26', 600, 302),
	('p27', 400, 470),
	('p28', 400, 208),
	('p29', 700, 292),
	('p30', 500, 686),
	('p31', 400, 547),
	('p32', 500, 257),
	('p33', 600, 564),
	('p34', 200, 211),
	('p35', 500, 233),
	('p36', 400, 293),
	('p37', 700, 552),
	('p38', 700, 812),
	('p39', 400, 541),
	('p40', 700, 441),
	('p41', 300, 875),
	('p42', 500, 691),
	('p43', 300, 572),
	('p44', 500, 572),
	('p45', 500, 663);

-- insert licenseMV data
insert into licenseMV (personID, license) values
    ('p1', 'jets'),
    ('p10', 'jets'),
    ('p11', 'jets'),
    ('p11', 'props'),
    ('p12', 'props'),
    ('p13', 'jets'),
    ('p14', 'jets'),
    ('p15', 'jets'),
    ('p15', 'props'),
    ('p15', 'testing'),
    ('p16', 'jets'),
    ('p17', 'jets'),
    ('p17', 'props'),
    ('p18', 'jets'),
    ('p19', 'jets'),
    ('p2', 'jets'),
    ('p2', 'props'),
    ('p20', 'jets'),
    ('p3', 'jets'),
    ('p4', 'jets'),
    ('p4', 'props'),
    ('p5', 'jets'),
    ('p6', 'jets'),
    ('p6', 'props'),
    ('p7', 'jets'),
    ('p8', 'props'),
    ('p9', 'jets'),
    ('p9', 'props'),
    ('p9', 'testing');
    
-- insert vacationMV data
insert into vacationMV (personID, destination, sequence) values
    ('p21', 'AMS', 1),
    ('p22', 'AMS', 1),
    ('p23', 'BER', 1),
    ('p24', 'MUC', 1),
    ('p24', 'CDG', 2),
    ('p25', 'MUC', 1),
    ('p26', 'MUC', 1),
    ('p27', 'BER', 1),
    ('p28', 'LGW', 1),
    ('p29', 'FCO', 1),
    ('p29', 'LHR', 2),
    ('p30', 'FCO', 1),
    ('p30', 'MAD', 2),
    ('p31', 'FCO', 1),
    ('p32', 'FCO', 1),
    ('p33', 'CAN', 1),
    ('p34', 'HND', 1),
    ('p35', 'LGW', 1),
    ('p36', 'FCO', 1),
    ('p37', 'FCO', 1),
    ('p37', 'LGW', 2),
    ('p37', 'CDG', 3),
    ('p38', 'MUC', 1),
    ('p39', 'MUC', 1),
    ('p40', 'HND', 1);