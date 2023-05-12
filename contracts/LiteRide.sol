// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiteRideToken.sol";
import "hardhat/console.sol";

contract LiteRide is Ownable {
    constructor(LiteRideToken _tokenAddress) {
        token = _tokenAddress;
    }

    error AlreadyExists();
    error DoesNotExist();
    error NotAllowed();
    error IncorrectAmount();
    error NotEnoughAllowance();
    error NotEnoughBalance();

    LiteRideToken public immutable token;

    uint256 public daoFee = 1; // 1% fee (This can be changed by the DAO using proposals)
    uint256 public baseFee = 4 * 10 ** 18; // 4 LTR (This can be changed by the DAO using proposals)
    uint256 public baseFeeDistance = 2; // 2 miles (This can be changed by the DAO using proposals)
    uint256 public distanceFee = 1 * 10 ** 18; // 1 LTR per 1 mile (This can be changed by the DAO using proposals)

    // the mapping of addresses signed up as drivers
    mapping(address => bool) public drivers;

    // the mapping of addresses signed up as riders
    mapping(address => bool) public riders;

    // struct for a ride
    struct Ride {
        address driver;
        address rider;
        uint256 distanceEstimated;
        uint256 distanceRecorded;
        string pickupCoordinates;
        string dropoffCoordinates;
        uint256 amountEstimate;
        uint256 amountPaid;
        uint256 requestBlock;
        uint256 acceptedBlock;
        uint256 startBlock;
        uint256 paymentBlock;
        uint256 endBlock;
    }

    // mapping of ride id to ride
    mapping(uint256 => Ride) private rides;

    // mapping of requested rides
    mapping(uint256 => Ride) private requestedRides;

    // mapping of active rides for a driver or rider
    mapping(address => uint256) private activeRides;

    uint256[] private requestedRideIds;
    uint256[] private activeRideIds;

    // Events
    event RideRequested(
        uint256 rideId,
        address driver,
        address rider,
        uint256 distanceEstimated,
        uint256 amountAgreed,
        string pickupCoordinates,
        string dropoffCoordinates,
        uint256 requestBlock
    );

    event RideAccepted(
        uint256 rideId,
        address driver,
        address rider,
        uint256 distanceEstimated,
        uint256 amountAgreed,
        string pickupCoordinates,
        string dropoffCoordinates,
        uint256 requestBlock,
        uint256 acceptedBlock
    );

    event RideStarted(
        uint256 rideId,
        address driver,
        address rider,
        uint256 distanceEstimated,
        uint256 amountAgreed,
        string pickupCoordinates,
        string dropoffCoordinates,
        uint256 requestBlock,
        uint256 acceptedBlock,
        uint256 startBlock
    );

    event RideEnded(uint256 rideId, address driver, address rider);

    // create a new driver
    function createDriver() public returns (bool) {
        if (drivers[msg.sender]) revert AlreadyExists(); // if driver is already registered, revert with custom error
        drivers[msg.sender] = true;
        return true;
    }

    // create a new rider
    function createRider() public returns (bool) {
        if (riders[msg.sender]) revert AlreadyExists(); // if rider is already registered, revert with custom error
        riders[msg.sender] = true;
        return true;
    }

    // check if rider is registered
    function isRider(address _rider) public view returns (bool) {
        return riders[_rider];
    }

    // check if driver is registered
    function isDriver(address _driver) public view returns (bool) {
        return drivers[_driver];
    }

    function updateDaoFee(uint256 _daoFee) public onlyOwner {
        daoFee = _daoFee;
    }

    function updateBaseFee(uint256 _baseFee) public onlyOwner {
        baseFee = _baseFee;
    }

    function updateDistanceFee(uint256 _distanceFee) public onlyOwner {
        distanceFee = _distanceFee;
    }

    function updateBaseFeeDistance(uint256 _baseFeeDistance) public onlyOwner {
        baseFeeDistance = _baseFeeDistance;
    }

    function getBaseFee() public view returns (uint256) {
        return baseFee;
    }

    function getDistanceFee() public view returns (uint256) {
        return distanceFee;
    }

    function getBaseFeeDistance() public view returns (uint256) {
        return baseFeeDistance;
    }

    function getDaoFee() public view returns (uint256) {
        return daoFee;
    }

    function getRide(uint256 _rideId) public view returns (Ride memory) {
        return rides[_rideId];
    }

    function getActiveRide() public view returns (Ride memory) {
        return rides[activeRides[msg.sender]];
    }

    function getRideRequests() public view returns (Ride[] memory) {
        // return all requested rides that are not yet started (i.e no driver assigned)
        // we show max 10 rides
        Ride[] memory requestedRidesResponse = new Ride[](10);

        uint256 requestedRidesCount = 0;

        // INFO: This is inefficient, because no location is considered, etc.
        // We'll need to implement a more efficient way to get the nearest rides
        // For now, we'll just return the first 10 requested rides
        for (uint256 i = 0; i < requestedRideIds.length; i++) {
            if (requestedRidesCount == 10) break;
            if (requestedRideIds[i] == 0) continue; // skip if ride id is 0 (ride does not exist)
            Ride memory ride = requestedRides[requestedRideIds[i]];
            requestedRidesResponse[requestedRidesCount] = ride;
            requestedRidesCount++;
        }

        return requestedRidesResponse;
    }

    function approveToken(uint256 _amount) public returns (bool) {
        // user needs to approve tokens to be spent by this contract
        // we'll then move the funds from the user to this contract
        // this is to avoid user spending funds during the ride
        // once the ride is completed, the funds will be moved from this contract to the driver
        token.approve(address(this), _amount);
        return true;
    }

    function requestRide(
        address rider,
        uint256 distanceEstimated,
        uint256 amountEstimate,
        string memory pickupCoordinates,
        string memory dropoffCoordinates
    ) public returns (bool) {
        if (!riders[rider]) revert DoesNotExist(); // if rider is not registered, revert with custom error

        //check if sender is the rider
        if (msg.sender != rider) revert NotAllowed();

        // get the start block
        uint256 requestBlock = block.number;

        console.log("rider: %s", rider);
        console.log("requestBlock: %s", requestBlock);

        uint256 requestedRideId = uint256(
            keccak256(abi.encodePacked(rider, requestBlock))
        ); // create a unique id for the ride, using the rider address and the request block

        console.log("requestedRideId: %s", requestedRideId);

        // check if ride is already existing in the requestedRides mapping
        if (requestedRides[requestedRideId].rider != address(0))
            revert AlreadyExists();

        uint256 calculatedAmountEstimate;

        if (distanceEstimated < baseFeeDistance) {
            // if distance is lesser than baseFeeDistance, this is the minimum amount to pay
            calculatedAmountEstimate = baseFee;
        } else {
            // check if the amount agreed is correct
            calculatedAmountEstimate =
                baseFee +
                (distanceFee * (distanceEstimated - baseFeeDistance));
        }

        if (calculatedAmountEstimate != amountEstimate)
            revert IncorrectAmount();

        uint256 riderBalance = token.balanceOf(rider);

        // check if rider has enough balance
        if (riderBalance < amountEstimate) revert NotEnoughBalance();

        // check if amount agreed is approved
        if (token.allowance(rider, address(this)) < amountEstimate)
            revert NotEnoughAllowance();

        // transfer the amount agreed to the contract, which acts as escrow
        token.transferFrom(rider, address(this), amountEstimate);

        // create a new ride and add it to the requestedRides mapping
        requestedRides[requestedRideId] = Ride(
            address(0),
            rider,
            distanceEstimated,
            0,
            pickupCoordinates,
            dropoffCoordinates,
            amountEstimate,
            0,
            requestBlock,
            0,
            0,
            0,
            0
        );

        // add the ride id to the requestedRideIds array
        requestedRideIds.push(requestedRideId);

        // emit an event to notify all drivers that a ride has been requested
        emit RideRequested(
            requestedRideId,
            address(0),
            rider,
            distanceEstimated,
            amountEstimate,
            pickupCoordinates,
            dropoffCoordinates,
            requestBlock
        );

        return true;
    }

    function acceptRide(
        address rider,
        uint256 requestBlock
    ) public returns (bool) {
        // check if sender is a driver
        if (!drivers[msg.sender]) revert DoesNotExist();

        console.log("rider: %s", rider);
        console.log("requestBlock: %s", requestBlock);

        uint256 requestedRideId = uint256(
            keccak256(abi.encodePacked(rider, requestBlock))
        ); // create a unique id for the ride, using the rider address and the request block

        console.log("requestedRideId: %s", requestedRideId);

        // check if ride exists
        if (requestedRides[requestedRideId].rider == address(0))
            revert DoesNotExist();

        // check if ride is already accepted
        if (requestedRides[requestedRideId].driver != address(0))
            revert AlreadyExists();

        // check if ride is already completed by checking if endBlock is already set to a value other than 0 for the ride
        if (requestedRides[requestedRideId].endBlock != 0) revert NotAllowed();

        // check if ride is already started by checking if startBlock is already set to a value other than 0 for the ride
        if (requestedRides[requestedRideId].startBlock != 0)
            revert NotAllowed();

        // if all checks are passed, assign the driver to the ride
        // we first move the ride from the requestedRides mapping to the rides mapping
        Ride memory ride = requestedRides[requestedRideId];

        ride.driver = msg.sender;
        ride.acceptedBlock = block.number;

        rides[requestedRideId] = ride;

        // we then remove the ride from the requestedRides mapping
        delete requestedRides[requestedRideId];

        // delete the ride id from the requestedRideIds array
        for (uint256 i = 0; i < requestedRideIds.length; i++) {
            if (requestedRideIds[i] == requestedRideId) {
                delete requestedRideIds[i];
                break;
            }
        }

        // set active ride for the driver and rider
        activeRides[msg.sender] = requestedRideId;
        activeRides[rider] = requestedRideId;

        // emit an event to notify the rider that the ride has been accepted
        emit RideAccepted(
            requestedRideId,
            ride.driver,
            ride.rider,
            ride.distanceEstimated,
            ride.amountEstimate,
            ride.pickupCoordinates,
            ride.dropoffCoordinates,
            ride.requestBlock,
            ride.acceptedBlock
        );

        return true;
    }

    function startRide(
        address rider,
        uint256 requestBlock
    ) public returns (bool) {
        // check if sender is the driver
        if (!drivers[msg.sender]) revert DoesNotExist();

        uint256 rideId = uint256(
            keccak256(abi.encodePacked(rider, requestBlock))
        ); // create a unique id for the ride, using the rider address and the request block

        // Check if ride exists
        if (rides[rideId].driver == address(0)) revert DoesNotExist();

        // Check if ride is already completed by checking if endBlock is already set to a value other than 0 for the ride
        if (rides[rideId].endBlock != 0) revert NotAllowed();

        // Check if ride is already started by checking if startBlock is already set to a value other than 0 for the ride
        if (rides[rideId].startBlock != 0) revert NotAllowed();

        uint256 startBlock = block.number;

        // update the ride with the start block
        rides[rideId].startBlock = startBlock;

        // emit an event to notify the rider and driver that the ride has started
        emit RideStarted(
            rideId,
            rides[rideId].driver,
            rides[rideId].rider,
            rides[rideId].distanceEstimated,
            rides[rideId].amountEstimate,
            rides[rideId].pickupCoordinates,
            rides[rideId].dropoffCoordinates,
            rides[rideId].requestBlock,
            rides[rideId].acceptedBlock,
            startBlock
        );

        return true;
    }

    function endRide(
        address rider,
        uint256 requestBlock,
        uint256 distanceRecorded
    ) public returns (bool) {
        // check if sender is the driver
        if (!drivers[msg.sender]) revert DoesNotExist();

        uint256 rideId = uint256(
            keccak256(abi.encodePacked(rider, requestBlock))
        ); // create a unique id for the ride, using the rider address and the request block

        // Check if ride exists
        if (rides[rideId].driver == address(0)) revert DoesNotExist();

        // Check if ride is already completed by checking if endBlock is already set to a value other than 0 for the ride
        if (rides[rideId].endBlock != 0) revert NotAllowed();

        // check if ride is started by checking if startBlock is already set to a value other than 0 for the ride
        if (rides[rideId].startBlock == 0) revert NotAllowed();

        uint256 calculatedAmount;

        calculatedAmount =
            baseFee +
            (distanceFee * (distanceRecorded - baseFeeDistance));

        console.log("calculatedAmount: %s", calculatedAmount);

        if (rides[rideId].amountEstimate > calculatedAmount) {
            // if amount is more, we need to refund the rider the difference
            uint256 excessAmountToRefund = rides[rideId].amountEstimate -
                calculatedAmount;

            console.log("excessAmountToRefund: %s", excessAmountToRefund);
            // transfer the excess amount to refund to the rider from the escrow address (i.e the contract)
            token.transfer(rides[rideId].rider, excessAmountToRefund);
        }

        // calculate the amount to pay the driver, which is the calculated amount minus the dao fee percentage
        uint256 daoFeeAmount = (calculatedAmount * daoFee) / 100;

        console.log("daoFeeAmount: %s", daoFeeAmount);

        uint256 amountToPayTheDriver = calculatedAmount - daoFeeAmount;

        console.log("amountToPayTheDriver: %s", amountToPayTheDriver);

        // transfer the amount to pay the driver to the driver
        token.transfer(rides[rideId].driver, amountToPayTheDriver);

        // transfer the dao fee amount to the dao address
        token.transfer(owner(), daoFeeAmount);

        // mark the ride as completed and update the remaining details
        rides[rideId].amountPaid = calculatedAmount;
        rides[rideId].distanceRecorded = distanceRecorded;
        rides[rideId].endBlock = block.number;

        // remove the ride from the active rides mapping
        delete activeRides[rides[rideId].driver];
        delete activeRides[rides[rideId].rider];

        // emit an event to notify the rider and driver that the ride has ended
        emit RideEnded(rideId, rides[rideId].driver, rides[rideId].rider);

        return true;
    }

    // receive ether function
    receive() external payable {}

    // fallback function don't do anything
    fallback() external payable {}
}
