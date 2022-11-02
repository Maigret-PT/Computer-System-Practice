module count_60(
    input wire rst,
    input wire clk,
    input wire en,
    output wire[7:0] count,
    output wire co
);
    wire co10,co10to6,co6;
    count_10 u_count_10(
    	.rst   (rst   ),
        .clk   (clk   ),
        .en    (en    ),
        .count (count[3:0] ),
        .co    (co10    )
    );
    assign co10to6 = co10 & en;
    count_6 u_count_6(
    	.rst   (rst   ),
        .clk   (clk   ),
        .en    (co10to6    ),
        .count (count[7:4] ),
        .co    (co6    )
    );
    assign co = co6 & co10to6;
endmodule



module count_10(
    input wire rst,
    input wire clk,
    input wire en,
    output reg [3:0] count,
    output wire co
);
    always @ (posedge clk) begin
        if (rst) begin
            count <= 4'b0;
            //co <= 1'b0;
        end
        else if (en) begin
            if (count == 4'd9) begin
                count <= 4'b0;
                //co = 1'b1;
            end
            else begin
                count <= count + 1'b1;
                //co <= 1'b0;
            end
        end
    end
    assign co = (count == 4'd9);
endmodule



module count_6(
    input wire rst,
    input wire clk,
    input wire en,
    output reg [3:0] count,
    output wire co
);
    always @ (posedge clk) begin
      if (rst) begin
        count <= 4'b0;
      end
      else if (en) begin
        if (count == 4'd5) begin
          count <= 4'd0;
        end
        else begin
          count <= count +1'b1;
        end
      end
    end
    assign co = (count == 4'd5);
endmodule