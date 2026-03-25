pragma solidity ^0.5.1;
 
 contract Agent {
    
    uint256 private constant ACCESS_FEE = 2 ether;

     struct student {
         string name;
        uint256 age;
         address[] teacherAccessList;
        uint256[] diagnosis;
         string record;
     }
    

     struct teacher {
         string name;
        uint256 age;
         address[] studentAccessList;
     }

    uint256 public creditPool;
 
     address[] public studentList;
     address[] public teacherList;
 
     mapping (address => student) studentInfo;
     mapping (address => teacher) teacherInfo;
     mapping (address => address) Empty;    
 
    event AgentAdded(address indexed agent, uint256 designation, string name, uint256 age);
    event AccessPermitted(address indexed studentAddr, address indexed teacherAddr, uint256 valueWei);
    event AccessRevoked(address indexed studentAddr, address indexed teacherAddr, uint256 valueWei);
    event RecordHashUpdated(address indexed studentAddr, string recordHash, address indexed updatedBy);
    event InsuranceClaimProcessed(address indexed studentAddr, address indexed teacherAddr, uint256 diagnosis);

    modifier onlyStudent(address addr) {
        require(bytes(studentInfo[addr].name).length > 0, "Student not registered");
        _;
    }

    modifier onlyTeacher(address addr) {
        require(bytes(teacherInfo[addr].name).length > 0, "Teacher not registered");
        _;
    }

    modifier onlyLinked(address saddr, address taddr) {
        require(hasAccess(saddr, taddr), "Student-teacher access link missing");
        _;
    }
 
    function add_agent(string memory _name, uint256 _age, uint256 _designation, string memory _hash) public returns(string memory){
         address addr = msg.sender;        
        require(bytes(_name).length > 0, "Name required");
        require(_age > 0, "Age required");
        require(bytes(studentInfo[addr].name).length == 0 && bytes(teacherInfo[addr].name).length == 0, "Already registered");

         if(_designation == 0){
            student storage p = studentInfo[addr];
             p.name = _name;
             p.age = _age;
             p.record = _hash;
            studentList.push(addr);
            emit AgentAdded(addr, _designation, _name, _age);
            emit RecordHashUpdated(addr, _hash, msg.sender);
             return _name;
         }

        if (_designation == 1){
            teacher storage d = teacherInfo[addr];
            d.name = _name;
            d.age = _age;
            teacherList.push(addr);
            emit AgentAdded(addr, _designation, _name, _age);
             return _name;


        }

        revert("Invalid designation");
     }
 
 
    function get_student(address addr) view public returns (string memory , uint256, uint256[] memory , address, string memory ){
         return (studentInfo[addr].name, studentInfo[addr].age, studentInfo[addr].diagnosis, Empty[addr], studentInfo[addr].record);
     }
 
    function get_teacher(address addr) view public returns (string memory , uint256){
         return (teacherInfo[addr].name, teacherInfo[addr].age);
     }

     function get_student_teacher_name(address saddr, address taddr) view public returns (string memory , string memory ){
         return (studentInfo[saddr].name,teacherInfo[taddr].name);
     }
 
    function permit_access(address addr) payable public onlyStudent(msg.sender) onlyTeacher(addr) {
        require(msg.value == ACCESS_FEE, "Access fee must be 2 ether");
        require(!hasAccess(msg.sender, addr), "Access already granted");

        creditPool += ACCESS_FEE;

        teacherInfo[addr].studentAccessList.push(msg.sender);
        studentInfo[msg.sender].teacherAccessList.push(addr);

        emit AccessPermitted(msg.sender, addr, ACCESS_FEE);
     }
 
    function set_hash_public (address saddr, string memory _hash) public onlyStudent(saddr) {
        require(msg.sender == saddr || hasAccess(saddr, msg.sender), "Only student or authorized teacher");
         set_hash(saddr, _hash);
     }
 
    // must be called by teacher linked to student
    function insurance_claimm(address saddr, uint256 _diagnosis, string memory  _hash) public onlyTeacher(msg.sender) onlyStudent(saddr) onlyLinked(saddr, msg.sender) {
        require(creditPool >= ACCESS_FEE, "Insufficient credit pool");

        creditPool -= ACCESS_FEE;
        msg.sender.transfer(ACCESS_FEE);

        set_hash(saddr, _hash);
        remove_student_internal(saddr, msg.sender);

        bool diagnosisFound = false;
        for(uint256 j = 0; j < studentInfo[saddr].diagnosis.length; j++){
            if(studentInfo[saddr].diagnosis[j] == _diagnosis) {
                diagnosisFound = true;
                break;
             }
         }
 
        if (!diagnosisFound) {
            studentInfo[saddr].diagnosis.push(_diagnosis);
        }

        emit InsuranceClaimProcessed(saddr, msg.sender, _diagnosis);
     }
 
    function remove_element_in_array(address[] storage arrayData, address addr) internal
     {
        bool check = false;
        uint256 del_index = 0;
        for(uint256 i = 0; i < arrayData.length; i++){
            if(arrayData[i] == addr){
                 check = true;
                 del_index = i;
                break;
             }
         }
        require(check, "Address not found");

        if(arrayData.length > 1) {
            arrayData[del_index] = arrayData[arrayData.length - 1];
        }
        arrayData.length--;
    }

    function remove_student(address saddr, address taddr) public onlyLinked(saddr, taddr) {
        require(
            msg.sender == saddr || msg.sender == taddr,
            "Only linked student or teacher can remove"
        );

        remove_student_internal(saddr, taddr);
     }
 
    function remove_student_internal(address saddr, address taddr) internal {
         remove_element_in_array(teacherInfo[taddr].studentAccessList, saddr);
         remove_element_in_array(studentInfo[saddr].teacherAccessList, taddr);
     }    

    function hasAccess(address saddr, address taddr) public view returns (bool) {
        for (uint256 i = 0; i < teacherInfo[taddr].studentAccessList.length; i++) {
            if (teacherInfo[taddr].studentAccessList[i] == saddr) {
                return true;
            }
        }
        return false;
    }

     function get_accessed_teacherlist_for_student(address addr) public view returns (address[] memory )
    {
        return studentInfo[addr].teacherAccessList;
     }

     function get_accessed_studentlist_for_teacher(address addr) public view returns (address[] memory )
     {
         return teacherInfo[addr].studentAccessList;
     }

    function revoke_access(address taddr) public onlyStudent(msg.sender) onlyTeacher(taddr) onlyLinked(msg.sender, taddr){
        require(creditPool >= ACCESS_FEE, "Insufficient credit pool");

        remove_student_internal(msg.sender,taddr);
        creditPool -= ACCESS_FEE;
        msg.sender.transfer(ACCESS_FEE);

        emit AccessRevoked(msg.sender, taddr, ACCESS_FEE);
     }
 
     function get_student_list() public view returns(address[] memory ){
         return studentList;
     }
 
     function get_teacher_list() public view returns(address[] memory ){
         return teacherList;
     }
 
     function get_hash(address saddr) public view returns(string memory ){
         return studentInfo[saddr].record;
     }
 
     function set_hash(address saddr, string memory _hash) internal {
         studentInfo[saddr].record = _hash;
         emit RecordHashUpdated(saddr, _hash, msg.sender);
     }
 }
