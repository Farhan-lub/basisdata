-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Waktu pembuatan: 25 Jul 2024 pada 07.30
-- Versi server: 10.4.32-MariaDB
-- Versi PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `petshop_pbd_fix`
--

DELIMITER $$
--
-- Prosedur
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `AddAppointment` (IN `petID` INT, IN `employeeID` INT, IN `appointmentDate` DATE, IN `appointmentTime` TIME)   BEGIN
INSERT INTO Appointment (Date, Time, PetID, EmployeeID) VALUES (appointmentDate, appointmentTime, petID, employeeID);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ScheduleAppointment` (IN `p_PetID` INT, IN `p_ServiceName` VARCHAR(100))   BEGIN
    DECLARE v_ServiceID INT;
    DECLARE v_EmployeeID INT;
    SELECT ServiceID INTO v_ServiceID FROM service WHERE Name = p_ServiceName;
    IF v_ServiceID IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid service name';
    ELSE
        CASE p_ServiceName
            WHEN 'Grooming' THEN SET v_EmployeeID = 2;
            WHEN 'Vaccination' THEN SET v_EmployeeID = 1;
            WHEN 'Boarding' THEN SET v_EmployeeID = 3;
            WHEN 'Training' THEN SET v_EmployeeID = 4;
            WHEN 'Consultation' THEN SET v_EmployeeID = 5;
            WHEN 'Dental Care' THEN SET v_EmployeeID = 6;
            ELSE SET v_EmployeeID = 1;
        END CASE;
        INSERT INTO appointment (Date, Time, PetID, EmployeeID)
        VALUES (CURDATE() + INTERVAL 1 DAY, '10:00:00', p_PetID, v_EmployeeID);
        INSERT INTO appointmentservice (AppointmentID, ServiceID, EmployeeID)
        VALUES (LAST_INSERT_ID(), v_ServiceID, v_EmployeeID);
        SELECT 'Appointment scheduled' AS Message;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdatePetVaccination` (IN `p_PetID` INT)   BEGIN
    DECLARE v_Species VARCHAR(50);
    DECLARE v_Age INT;
    DECLARE v_VaccinationStatus VARCHAR(255);
    DECLARE v_LastCheckupDate DATE;
    DECLARE v_CurrentDate DATE;
    
    SELECT Species, Age INTO v_Species, v_Age
    FROM pet
    WHERE PetID = p_PetID;
    
    SELECT Vaccination, LastCheckupDate INTO v_VaccinationStatus, v_LastCheckupDate
    FROM medicalrecord
    WHERE PetID = p_PetID;
    
    SET v_CurrentDate = CURDATE();
    IF v_VaccinationStatus IS NULL THEN
        INSERT INTO medicalrecord (PetID, Vaccination, LastCheckupDate)
        VALUES (p_PetID, '', v_CurrentDate);
    END IF;
    CASE 
        WHEN v_Species = 'Dog' THEN
            IF v_Age < 1 THEN
                SET v_VaccinationStatus = 'Needs puppy vaccinations';
            ELSEIF v_Age >= 1 AND (v_LastCheckupDate IS NULL OR DATEDIFF(v_CurrentDate, v_LastCheckupDate) > 365) THEN
                SET v_VaccinationStatus = 'Needs annual booster';
            ELSE
                SET v_VaccinationStatus = 'Up to date';
            END IF;
        
        WHEN v_Species = 'Cat' THEN
            IF v_Age < 1 THEN
                SET v_VaccinationStatus = 'Needs kitten vaccinations';
            ELSEIF v_Age >= 1 AND (v_LastCheckupDate IS NULL OR DATEDIFF(v_CurrentDate, v_LastCheckupDate) > 365) THEN
                SET v_VaccinationStatus = 'Needs annual booster';
            ELSE
                SET v_VaccinationStatus = 'Up to date';
            END IF;
        
        WHEN v_Species = 'Rabbit' THEN
            IF v_LastCheckupDate IS NULL OR DATEDIFF(v_CurrentDate, v_LastCheckupDate) > 365 THEN
                SET v_VaccinationStatus = 'Needs annual checkup';
            ELSE
                SET v_VaccinationStatus = 'Up to date';
            END IF;
        
        ELSE
            SET v_VaccinationStatus = 'Consult veterinarian for vaccination schedule';
    END CASE;
    
    UPDATE medicalrecord
    SET Vaccination = v_VaccinationStatus,
        LastCheckupDate = CASE 
                            WHEN v_VaccinationStatus != 'Up to date' THEN v_CurrentDate
                            ELSE LastCheckupDate
                          END
    WHERE PetID = p_PetID;
    SELECT CONCAT('Pet ID ', p_PetID, ' vaccination status: ', v_VaccinationStatus) AS Result;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `UpdateVaccinationStatus` ()   BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE pet_id INT;
    DECLARE last_checkup DATE;
    DECLARE cur CURSOR FOR SELECT PetID, LastCheckupDate FROM medicalrecord;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur;

    update_loop: LOOP
        FETCH cur INTO pet_id, last_checkup;
        IF done THEN
            LEAVE update_loop;
        END IF;

        IF last_checkup IS NULL THEN
            UPDATE medicalrecord SET Vaccination = 'Needs vaccination' WHERE PetID = pet_id;
        ELSE
            CASE
                WHEN DATEDIFF(CURDATE(), last_checkup) > 365 THEN
                    UPDATE medicalrecord SET Vaccination = 'Needs annual booster' WHERE PetID = pet_id;
                WHEN DATEDIFF(CURDATE(), last_checkup) > 180 THEN
                    UPDATE medicalrecord SET Vaccination = 'Due for checkup' WHERE PetID = pet_id;
                ELSE
                    UPDATE medicalrecord SET Vaccination = 'Up to date' WHERE PetID = pet_id;
            END CASE;
        END IF;
    END LOOP;

    CLOSE cur;
END$$

--
-- Fungsi
--
CREATE DEFINER=`root`@`localhost` FUNCTION `GetPets` (`pet_species` VARCHAR(50), `pet_breed` VARCHAR(50)) RETURNS INT(11)  BEGIN
    DECLARE total INT;
    SELECT COUNT(*) INTO total 
    FROM Pet
    WHERE Species = pet_species AND Breed = pet_breed;
    RETURN total;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `GetTotalAppointments` () RETURNS INT(11)  BEGIN
    DECLARE total INT;
    SELECT COUNT(*) INTO total FROM Appointment;
    RETURN total;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Struktur dari tabel `appointment`
--

CREATE TABLE `appointment` (
  `AppointmentID` int(11) NOT NULL,
  `Date` date DEFAULT NULL,
  `Time` time DEFAULT NULL,
  `PetID` int(11) DEFAULT NULL,
  `EmployeeID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `appointment`
--

INSERT INTO `appointment` (`AppointmentID`, `Date`, `Time`, `PetID`, `EmployeeID`) VALUES
(7, '2024-06-20', '10:00:00', 1, 1),
(8, '2024-06-21', '11:00:00', 2, 2),
(9, '2024-06-22', '12:00:00', 3, 3),
(10, '2024-06-23', '13:00:00', 4, 4),
(11, '2024-06-24', '14:00:00', 5, 5),
(12, '2024-06-25', '15:00:00', 6, 6),
(13, '2024-06-30', '10:00:00', 1, 1),
(14, '2024-07-26', '10:00:00', 1, 2);

--
-- Trigger `appointment`
--
DELIMITER $$
CREATE TRIGGER `before_appointment_insert` BEFORE INSERT ON `appointment` FOR EACH ROW BEGIN
    DECLARE conflict_count INT;
    SELECT COUNT(*)
    INTO conflict_count
    FROM Appointment
    WHERE Date = NEW.Date 
    AND Time = NEW.Time AND EmployeeID = NEW.EmployeeID;
    IF conflict_count > 0 THEN
        SET NEW.Time = ADDTIME(NEW.Time, '01:00:00');
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struktur dari tabel `appointmentservice`
--

CREATE TABLE `appointmentservice` (
  `AppointmentID` int(11) NOT NULL,
  `ServiceID` int(11) NOT NULL,
  `EmployeeID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `appointmentservice`
--

INSERT INTO `appointmentservice` (`AppointmentID`, `ServiceID`, `EmployeeID`) VALUES
(7, 1, 1),
(8, 2, 2),
(14, 1, 2),
(9, 3, 3),
(10, 4, 4),
(11, 5, 5),
(12, 6, 6);

-- --------------------------------------------------------

--
-- Struktur dari tabel `customer`
--

CREATE TABLE `customer` (
  `CustomerID` int(11) NOT NULL,
  `Name` varchar(100) NOT NULL,
  `Email` varchar(100) DEFAULT NULL,
  `Phone` varchar(15) DEFAULT NULL,
  `Address` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `customer`
--

INSERT INTO `customer` (`CustomerID`, `Name`, `Email`, `Phone`, `Address`) VALUES
(1, 'John Doe', 'john@example.com', '1234567890', '123 Main St'),
(2, 'Jane Smith', 'jane@example.com', '0987654321', '456 Oak Ave'),
(3, 'Alice Johnson', 'alice@example.com', '5556667777', '789 Pine Rd'),
(4, 'Bob Brown', 'bob@example.com', '1112223333', '321 Birch Blvd'),
(5, 'Carol White', 'carol@example.com', '4445556666', '654 Maple Lane'),
(6, 'Dave Black', 'dave@example.com', '7778889999', '987 Elm St');

-- --------------------------------------------------------

--
-- Struktur dari tabel `employee`
--

CREATE TABLE `employee` (
  `EmployeeID` int(11) NOT NULL,
  `Name` varchar(100) NOT NULL,
  `Email` varchar(100) DEFAULT NULL,
  `Phone` varchar(15) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `employee`
--

INSERT INTO `employee` (`EmployeeID`, `Name`, `Email`, `Phone`) VALUES
(1, 'Dr. Smith', 'dr.smith@example.com', '5551234567'),
(2, 'Anna Johnson', 'anna.johnson@example.com', '5559876543'),
(3, 'Sarah Brown', 'sarah.brown@example.com', '5551112222'),
(4, 'Mike Davis', 'mike.davis@example.com', '5554445555'),
(5, 'Emily White', 'emily.white@example.com', '5557778888'),
(6, 'Tom Wilson', 'tom.wilson@example.com', '5553339999');

-- --------------------------------------------------------

--
-- Struktur dari tabel `medicalrecord`
--

CREATE TABLE `medicalrecord` (
  `MedicalRecordID` int(11) NOT NULL,
  `PetID` int(11) DEFAULT NULL,
  `Vaccination` varchar(255) DEFAULT NULL,
  `LastCheckupDate` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `medicalrecord`
--

INSERT INTO `medicalrecord` (`MedicalRecordID`, `PetID`, `Vaccination`, `LastCheckupDate`) VALUES
(1, 1, 'Due for checkup', '2023-12-15'),
(2, 2, 'Due for checkup', '2024-01-20'),
(3, 3, 'Up to date', '2024-02-10'),
(4, 4, 'Needs vaccination', NULL),
(5, 5, 'Due for checkup', '2023-11-05'),
(6, 6, 'Up to date', '2024-03-18');

-- --------------------------------------------------------

--
-- Struktur dari tabel `pet`
--

CREATE TABLE `pet` (
  `PetID` int(11) NOT NULL,
  `Name` varchar(50) NOT NULL,
  `Species` varchar(50) DEFAULT NULL,
  `Breed` varchar(50) DEFAULT NULL,
  `Age` int(11) DEFAULT NULL,
  `CustomerID` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `pet`
--

INSERT INTO `pet` (`PetID`, `Name`, `Species`, `Breed`, `Age`, `CustomerID`) VALUES
(1, 'Max', 'Dog', 'Labrador', 5, 1),
(2, 'Bella', 'Cat', 'Siamese', 3, 2),
(3, 'Charlie', 'Dog', 'Beagle', 4, 3),
(4, 'Daisy', 'Rabbit', 'Netherland', 2, 4),
(5, 'Rocky', 'Dog', 'Bulldog', 6, 5),
(6, 'Molly', 'Cat', 'Persian', 1, 6);

-- --------------------------------------------------------

--
-- Struktur dari tabel `service`
--

CREATE TABLE `service` (
  `ServiceID` int(11) NOT NULL,
  `Name` varchar(100) NOT NULL,
  `Description` text DEFAULT NULL,
  `Price` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `service`
--

INSERT INTO `service` (`ServiceID`, `Name`, `Description`, `Price`) VALUES
(1, 'Grooming', 'Full grooming services', 50.00),
(2, 'Vaccination', 'Vaccination for common diseases', 30.00),
(3, 'Boarding', 'Overnight stay for pets', 40.00),
(4, 'Training', 'Basic obedience training', 60.00),
(5, 'Consultation', 'Medical consultation for pets', 45.00),
(6, 'Dental Care', 'Dental cleaning and care', 55.00);

--
-- Indexes for dumped tables
--

--
-- Indeks untuk tabel `appointment`
--
ALTER TABLE `appointment`
  ADD PRIMARY KEY (`AppointmentID`),
  ADD KEY `PetID` (`PetID`),
  ADD KEY `EmployeeID` (`EmployeeID`),
  ADD KEY `idx_petid` (`PetID`),
  ADD KEY `idx_employeeid` (`EmployeeID`),
  ADD KEY `idx_date` (`Date`);

--
-- Indeks untuk tabel `appointmentservice`
--
ALTER TABLE `appointmentservice`
  ADD PRIMARY KEY (`AppointmentID`,`ServiceID`),
  ADD KEY `ServiceID` (`ServiceID`),
  ADD KEY `EmployeeID` (`EmployeeID`),
  ADD KEY `idx_employeeid` (`EmployeeID`),
  ADD KEY `idx_appointmentid` (`AppointmentID`),
  ADD KEY `idx_serviceid` (`ServiceID`);

--
-- Indeks untuk tabel `customer`
--
ALTER TABLE `customer`
  ADD PRIMARY KEY (`CustomerID`),
  ADD KEY `idx_name` (`Name`),
  ADD KEY `idx_phone` (`Phone`);

--
-- Indeks untuk tabel `employee`
--
ALTER TABLE `employee`
  ADD PRIMARY KEY (`EmployeeID`),
  ADD KEY `idx_name` (`Name`),
  ADD KEY `idx_phone` (`Phone`);

--
-- Indeks untuk tabel `medicalrecord`
--
ALTER TABLE `medicalrecord`
  ADD PRIMARY KEY (`MedicalRecordID`),
  ADD UNIQUE KEY `PetID` (`PetID`),
  ADD KEY `idx_petid` (`PetID`);

--
-- Indeks untuk tabel `pet`
--
ALTER TABLE `pet`
  ADD PRIMARY KEY (`PetID`),
  ADD KEY `CustomerID` (`CustomerID`),
  ADD KEY `idx_name` (`Name`),
  ADD KEY `idx_species` (`Species`);

--
-- Indeks untuk tabel `service`
--
ALTER TABLE `service`
  ADD PRIMARY KEY (`ServiceID`),
  ADD KEY `idx_name` (`Name`);

--
-- AUTO_INCREMENT untuk tabel yang dibuang
--

--
-- AUTO_INCREMENT untuk tabel `appointment`
--
ALTER TABLE `appointment`
  MODIFY `AppointmentID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT untuk tabel `customer`
--
ALTER TABLE `customer`
  MODIFY `CustomerID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT untuk tabel `employee`
--
ALTER TABLE `employee`
  MODIFY `EmployeeID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT untuk tabel `medicalrecord`
--
ALTER TABLE `medicalrecord`
  MODIFY `MedicalRecordID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT untuk tabel `pet`
--
ALTER TABLE `pet`
  MODIFY `PetID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT untuk tabel `service`
--
ALTER TABLE `service`
  MODIFY `ServiceID` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- Ketidakleluasaan untuk tabel pelimpahan (Dumped Tables)
--

--
-- Ketidakleluasaan untuk tabel `appointment`
--
ALTER TABLE `appointment`
  ADD CONSTRAINT `appointment_ibfk_1` FOREIGN KEY (`PetID`) REFERENCES `pet` (`PetID`),
  ADD CONSTRAINT `appointment_ibfk_2` FOREIGN KEY (`EmployeeID`) REFERENCES `employee` (`EmployeeID`);

--
-- Ketidakleluasaan untuk tabel `appointmentservice`
--
ALTER TABLE `appointmentservice`
  ADD CONSTRAINT `appointmentservice_ibfk_1` FOREIGN KEY (`AppointmentID`) REFERENCES `appointment` (`AppointmentID`),
  ADD CONSTRAINT `appointmentservice_ibfk_2` FOREIGN KEY (`ServiceID`) REFERENCES `service` (`ServiceID`),
  ADD CONSTRAINT `appointmentservice_ibfk_3` FOREIGN KEY (`EmployeeID`) REFERENCES `employee` (`EmployeeID`);

--
-- Ketidakleluasaan untuk tabel `medicalrecord`
--
ALTER TABLE `medicalrecord`
  ADD CONSTRAINT `medicalrecord_ibfk_1` FOREIGN KEY (`PetID`) REFERENCES `pet` (`PetID`);

--
-- Ketidakleluasaan untuk tabel `pet`
--
ALTER TABLE `pet`
  ADD CONSTRAINT `pet_ibfk_1` FOREIGN KEY (`CustomerID`) REFERENCES `customer` (`CustomerID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
