module com.fuqianshan {
    requires javafx.controls;
    requires javafx.fxml;

    opens com.fuqianshan to javafx.fxml;
    exports com.fuqianshan;
}
