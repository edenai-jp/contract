// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ERC20Interface {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function transfer(address _to, uint256 _value) external;
    function approve(address _spender, uint256 _value) external returns (bool);
    function allowance(address owner, address spender) external returns (uint256);
    function symbol() external view returns (string memory);    
    function balanceOf(address account) external returns (uint256);
}

interface ERC721Interface {
  function transferFrom(address _from, address _to, uint256 _tokenId) external ;
  function ownerOf(uint256 _tokenId) external returns (address);
  function approve(address _to, uint256 _tokenId) external;
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {

    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor (){
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract EdenAIRental is Ownable {

    uint  public rentalFee = 10;

    struct RentalNFT {
        address nftContract;
        uint256 tokenId;
        address tokenContract;
        uint256 price;
        uint rentalDays;
        address payable  owner;
        address rentalAddress;
        uint256 rentalTime;
        uint status; // 0-invalid、1-listing、2-rentaling
    }

    mapping (address => mapping (uint256 => RentalNFT)) public  nfts;

    event ListNFT(address _nftContract,uint256 _tokenId,address _tokenContract,uint256 _price,uint _rentalDays);

    event OffRentalNFT(address _nftContract,uint256 _tokenId);

    event Rental(address _nftContract,uint256 _tokenId,address _rentalAddress);

    event GetBackNFT(address _nftContract,uint256 _tokenId,address _rentalAddress);


    constructor(){
        
    }


    function modifyRentalFee(uint fee) public onlyOwner {
        require(fee>=0 && fee< 100,"EdenAIRental: invalid fee");
        rentalFee = fee;
    }

    function listRentalNFT(address nftContract,uint256 tokenId,address tokenContract,uint256 price,uint rentalDays) public {

        require(ERC721Interface(nftContract).ownerOf(tokenId) == msg.sender);
        // require(rentalDays>=7);

        ERC721Interface(nftContract).transferFrom(msg.sender,address(this),tokenId);

        RentalNFT storage nft = nfts[nftContract][tokenId];
        nft.nftContract = nftContract;
        nft.tokenId = tokenId;
        nft.rentalDays = rentalDays;
        nft.price = price;
        nft.tokenContract = tokenContract;
        nft.owner = payable (msg.sender);
        nft.status = 1;
        nft.rentalAddress = address(0);
        nft.rentalTime = 0;

        emit ListNFT(nftContract,tokenId,tokenContract,price,rentalDays);
    }


    function offRentalNFT(address nftContract,uint256 tokenId) public {

        RentalNFT storage nft = nfts[nftContract][tokenId];
        require(nft.owner == msg.sender,"EdenAIRental: msg.sender is not owner");
        require(nft.status == 1,"EdenAIRental: NFT is not listing");
        ERC721Interface(nftContract).transferFrom(address(this),msg.sender,tokenId);
        nft.status = 0;

        emit OffRentalNFT(nftContract,tokenId);
    }


    function rental(address nftContract,uint256 tokenId,address toAddress) payable public {

        RentalNFT storage nft = nfts[nftContract][tokenId];
        require(nft.status == 1,"EdenAIRental: NFT is not listing");

        //pay coin

        if (nft.price != 0){

            uint256 feeValue = nft.price * rentalFee / 100;
            uint256 getValue = nft.price - feeValue;

            if(nft.tokenContract == address(0)){
                require(msg.value == nft.price,"EdenAIRental: Insufficient value of payment token");

                payable(owner).transfer(feeValue);
                nft.owner.transfer(getValue);
            }else{
                require(ERC20Interface(nft.tokenContract).balanceOf(msg.sender) >= nft.price,"EdenAIRental: Insufficient balance  of payment token");
                require(ERC20Interface(nft.tokenContract).allowance(msg.sender,address(this)) >= nft.price,"EdenAIRental: Insufficient allownce of payment token");

                ERC20Interface(nft.tokenContract).transferFrom(msg.sender,owner,feeValue);
                ERC20Interface(nft.tokenContract).transferFrom(msg.sender,nft.owner,getValue);
            }
        }

        nft.status=2;
        nft.rentalAddress = toAddress;
        nft.rentalTime = block.timestamp;

        emit Rental(nftContract, tokenId, toAddress);
    }

    function getbackNFT(address nftContract,uint256 tokenId,uint isOff) public {

        RentalNFT storage nft = nfts[nftContract][tokenId];
        require(nft.owner == msg.sender,"EdenAIRental: msg.sender is not owner");
        require(nft.status == 2,"EdenAIRental: NFT is not rentaling");
        require(block.timestamp - nft.rentalTime >= nft.rentalDays * 1 days,"EdenAIRental: Rental NFT has not yet expired");

        nft.status = 1;
        nft.rentalAddress = address(0);
        nft.rentalTime = 0;

        emit GetBackNFT(nftContract,tokenId,nft.rentalAddress);
        
        if (isOff == 1){
            offRentalNFT(nftContract,tokenId);
        }
    }
}